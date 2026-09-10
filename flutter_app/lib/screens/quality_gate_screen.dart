import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/patient.dart';
import '../services/api_service.dart';
import 'results_screen.dart';

class QualityGateScreen extends StatefulWidget {
  final Patient patient;
  const QualityGateScreen({super.key, required this.patient});

  @override
  State<QualityGateScreen> createState() => _QualityGateScreenState();
}

class _QualityGateScreenState extends State<QualityGateScreen> {
  final ApiService _apiService = ApiService();
  String _selectedEye = 'OD'; // OD (Right) or OS (Left)
  String _cameraPreset = 'Forus 3nethra Classic';
  bool _isAssessing = false;
  bool _isQualityChecked = false;
  bool _qualityPassed = false;
  // Offline capture queued without a server verdict: proceeding is an
  // explicit override, tracked separately so it can never read as "passed".
  bool _isOfflinePending = false;
  String _qualityMessage = 'Awaiting server quality gate...';
  double? _qualityScore;
  String _qualityGrade = 'PENDING';
  String _selectedAssetImage = 'assets/images/scenario_1_good.jpg';

  final List<Map<String, String>> _sampleImages = [
    {'name': 'Clear Fundus (Good)', 'path': 'assets/images/scenario_1_good.jpg', 'quality': 'pass'},
    {'name': 'Motion Blur / Defocused (Bad)', 'path': 'assets/images/scenario_2_bad.jpg', 'quality': 'fail'},
    {'name': 'Marginal Illumination (Borderline)', 'path': 'assets/images/scenario_3_borderline.jpg', 'quality': 'borderline'},
    {'name': 'Severe NPDR (Referral)', 'path': 'assets/images/3_severe_eye_referral.jpg', 'quality': 'pass'},
  ];

  Future<void> _runQualityCheck(String assetPath) async {
    if (!mounted) return;
    setState(() {
      _isAssessing = true;
      _selectedAssetImage = assetPath;
    });

    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final result = await _apiService.assessQuality(bytes, cameraProfile: _cameraPreset);

      if (!mounted) return;
      final grade = (result['quality_grade'] ?? 'BAD').toString();
      final reasonsList = (result['rejection_reasons'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final reasons = reasonsList.join(' ');
      final operatorAction = (result['operator_action'] ?? '').toString();
      final hindiTip = (result['audio_guidance_hindi'] ?? '').toString();
      final detail = [reasons, operatorAction].where((s) => s.isNotEmpty).join(' ');
      final score = (result['quality_score'] as num?)?.toDouble();
      final scoreTxt = score != null ? ' (Score: ${(score * 100).toInt()}%)' : '';
      setState(() {
        _isAssessing = false;
        _isQualityChecked = true;
        _qualityGrade = grade;
        _qualityScore = score;
        if (grade == 'GOOD') {
          _qualityPassed = true;
          _isOfflinePending = false;
          _qualityMessage = 'Quality Verified$scoreTxt • $operatorAction';
        } else if (grade == 'BORDERLINE') {
          _qualityPassed = true;
          _isOfflinePending = false;
          _qualityMessage = 'Borderline quality$scoreTxt — proceeding under reassessment. $detail'
              '${hindiTip.isNotEmpty ? "\nहिंदी: $hindiTip" : ""}';
        } else if (grade == 'PENDING_SYNC') {
          _qualityPassed = false;
          _isOfflinePending = true;
          _qualityMessage = 'Offline — image queued; server quality gate runs on sync. $detail';
        } else {
          _qualityPassed = false;
          _isOfflinePending = false;
          _qualityMessage = 'Retake Required$scoreTxt. $detail'
              '${hindiTip.isNotEmpty ? "\nहिंदी: $hindiTip" : ""}';
        }
      });
    } catch (e) {
      // Asset could not be loaded, or the server rejected the check
      // (400/401/404/413/422/429) — nothing to claim.
      if (!mounted) return;
      setState(() {
        _isAssessing = false;
        _isQualityChecked = true;
        _qualityPassed = false;
        _isOfflinePending = false;
        _qualityScore = null;
        _qualityGrade = 'ERROR';
        _qualityMessage = 'Quality check unavailable: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Pre-evaluate default image (deliberately unawaited in initState).
    unawaited(_runQualityCheck(_selectedAssetImage));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Retinal Viewfinder ($_selectedEye)', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hardware and Eye Selectors
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _cameraPreset,
                      decoration: InputDecoration(
                        labelText: 'Hardware Camera Preset',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: ['Forus 3nethra Classic', 'Remidio FOP', 'Volk iNview', 'Generic Fundus Camera']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _cameraPreset = v ?? _cameraPreset;
                          // Thresholds changed: prior verdict is stale, re-gate.
                          _isQualityChecked = false;
                        });
                        _runQualityCheck(_selectedAssetImage);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'OD', label: Text('OD (R)')),
                      ButtonSegment(value: 'OS', label: Text('OS (L)')),
                    ],
                    selected: {_selectedEye},
                    onSelectionChanged: (s) => setState(() => _selectedEye = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Viewfinder Reticle Frame
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular Retinal Image Preview
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          _selectedAssetImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.shade900,
                            child: const Center(
                              child: Icon(Icons.remove_red_eye, color: Colors.white54, size: 60),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Optical HUD Target Ring
                    Container(
                      width: 270,
                      height: 270,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _qualityPassed ? Colors.greenAccent : Colors.amberAccent,
                          width: 2.5,
                        ),
                      ),
                    ),

                    // Center Crosshair Target
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 1.5),
                      ),
                    ),

                    // Server-verdict pill: reflects the actual gate outcome,
                    // never a sensor claim (no focus/illumination metrics exist).
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _qualityPassed ? Icons.check_circle : Icons.warning_amber,
                              size: 14,
                              color: _qualityPassed ? Colors.greenAccent : Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              !_isQualityChecked || _isAssessing
                                  ? 'Assessing…'
                                  : 'Server verdict: $_qualityGrade',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Image Selector for Live Testing / Demo
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library, size: 20, color: Color(0xFF1A56DB)),
                      const SizedBox(width: 8),
                      const Text('Test Image:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedAssetImage,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _sampleImages.map((s) {
                            return DropdownMenuItem(
                              value: s['path']!,
                              child: Text(s['name']!, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (path) {
                            if (path != null) {
                              _runQualityCheck(path);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quality Assessment Verdict Banner
              if (_isAssessing || !_isQualityChecked)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else if (_isOfflinePending) ...[
                // OFFLINE: no server verdict exists. Proceeding queues the
                // capture without a quality check — explicit override only.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1A56DB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_off, color: Color(0xFF1A56DB), size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _qualityMessage,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'No quality verdict exists for this image. The server gate runs automatically on sync.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56DB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Queue Without Quality Check (offline override) →',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultsScreen(
                          patient: widget.patient,
                          eyeSide: _selectedEye == 'OD' ? 'Right' : 'Left',
                          cameraProfile: _cameraPreset,
                          assetImagePath: _selectedAssetImage,
                        ),
                      ),
                    );
                  },
                ),
              ] else if (!_qualityPassed) ...[
                // REJECTED / BLURRY BANNER (The Key SIH Demo Requirement!)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB45309)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Color(0xFFB45309), size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _qualityMessage,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      const Text('ASHA Alignment Protocol:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text('1. Move camera 2 cm closer to pupil.', style: TextStyle(fontSize: 12)),
                      const Text('2. Instruct patient to fixate directly on green internal LED target.', style: TextStyle(fontSize: 12)),
                      const Text('3. Dim room light to achieve natural non-mydriatic dilation.', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 10),

                      // Vernacular Audio Pill
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
                          foregroundColor: const Color(0xFF92400E),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFD97706)),
                        ),
                        icon: const Icon(Icons.volume_up, size: 18),
                        label: const Text('📋 Hindi guidance script: "कृपया कैमरा 2 सेमी पास लाएं"', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Demo: audio playback not wired — read the script above to the patient.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Retake Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('🔄 Retake Photograph (Safe Abstention)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _runQualityCheck(_selectedAssetImage),
                ),
              ] else ...[
                // PASSED BANNER
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _qualityMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Proceed Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56DB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Run AI Diagnostic Triage →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultsScreen(
                          patient: widget.patient,
                          eyeSide: _selectedEye == 'OD' ? 'Right' : 'Left',
                          cameraProfile: _cameraPreset,
                          assetImagePath: _selectedAssetImage,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
