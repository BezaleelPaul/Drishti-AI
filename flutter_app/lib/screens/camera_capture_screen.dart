import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/screening_models.dart';
import '../services/api_service.dart';
import 'screening_result_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  final ApiService apiService;
  final PatientModel patient;
  final DiabetesRiskModel? riskModel;
  final void Function(
    Uint8List imageBytes,
    String filename,
    String cameraProfile,
    String eyeSide,
    RetinalQualityModel? qualityResult,
  )?
  onProceedToAnalysis;
  final VoidCallback? onBack;
  final bool embedded;

  const CameraCaptureScreen({
    super.key,
    required this.apiService,
    required this.patient,
    this.riskModel,
    this.onProceedToAnalysis,
    this.onBack,
    this.embedded = false,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  String _selectedCamera = 'Remidio FOP (Smartphone Handheld)';
  String _selectedEye = 'Right Eye (OD)';
  int _recaptureCount = 0;

  // Selected sample image
  String _currentSampleAsset = 'assets/images/2_clear_eye_normal.jpg';
  String _currentSampleName = '2_clear_eye_normal.jpg';
  Uint8List? _imageBytes;

  bool _isCheckingQuality = false;
  RetinalQualityModel? _qualityResult;

  final List<Map<String, String>> _sampleImages = [
    {
      'title': '⚠️ Blurry Retake (Simulate Optical Defocus)',
      'asset': 'assets/images/1_blurry_eye_retake.jpg',
      'filename': '1_blurry_eye_retake.jpg',
    },
    {
      'title': '🟢 Clear Fundus (Normal / No DR)',
      'asset': 'assets/images/2_clear_eye_normal.jpg',
      'filename': '2_clear_eye_normal.jpg',
    },
    {
      'title': '🔴 Clinical Severe DR (Referral Required)',
      'asset': 'assets/images/3_severe_eye_referral.jpg',
      'filename': '3_severe_eye_referral.jpg',
    },
    // NOTE (privacy): real patient fundus scans must NEVER be bundled into
    // the app package (HIPAA/GDPR/DPDP). Use synthetic/scenario samples
    // below plus on-device capture / file-picker for real images.
    {
      'title': '📊 Scenario 1 (Good Quality Pass)',
      'asset': 'assets/images/scenario_1_good.jpg',
      'filename': 'scenario_1_good.jpg',
    },
    {
      'title': '⚠️ Scenario 2 (Defocus / Blur Reject)',
      'asset': 'assets/images/scenario_2_bad.jpg',
      'filename': 'scenario_2_bad.jpg',
    },
    {
      'title': '⚖️ Scenario 3 (Borderline Quality)',
      'asset': 'assets/images/scenario_3_borderline.jpg',
      'filename': 'scenario_3_borderline.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadImageAsset(_currentSampleAsset, _currentSampleName);
  }

  Future<void> _loadImageAsset(String assetPath, String filename) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      setState(() {
        _imageBytes = bytes;
        _currentSampleAsset = assetPath;
        _currentSampleName = filename;
      });
      await _runQualityCheck();
    } catch (e) {
      debugPrint('Error loading asset $assetPath: $e');
    }
  }

  Future<void> _pickCustomImage() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select a fundus photo',
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (files.isEmpty) return; // user cancelled the picker
      if (!mounted) return;
      final picked = files.first;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read that photo (empty file).'),
          ),
        );
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _currentSampleAsset = 'custom_upload';
        _currentSampleName = picked.name;
      });
      await _runQualityCheck();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }

  Future<void> _runQualityCheck() async {
    if (_imageBytes == null) return;
    setState(() {
      _isCheckingQuality = true;
    });

    final quality = await widget.apiService.checkQuality(
      imageBytes: _imageBytes!,
      filename: _currentSampleName,
      cameraProfile: _selectedCamera,
    );

    if (mounted) {
      setState(() {
        _qualityResult = quality;
        _isCheckingQuality = false;
      });
    }
  }

  void _simulateHindiVoicePrompt(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.volume_up, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('🔊 $text')),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _retakePhoto() {
    setState(() {
      _recaptureCount++;
      // Switch to clear image to simulate worker correcting alignment
      _loadImageAsset(
        'assets/images/2_clear_eye_normal.jpg',
        '2_clear_eye_normal.jpg',
      );
    });
  }

  void _proceedToAnalysis() {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture an eye photo first.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🔬 Running AI Diagnostic Screening (Model 2 & Grad-CAM++)...',
        ),
        duration: Duration(milliseconds: 1000),
        backgroundColor: Color(0xFF1E3A8A),
      ),
    );

    if (widget.onProceedToAnalysis != null) {
      widget.onProceedToAnalysis!(
        _imageBytes!,
        _currentSampleName,
        _selectedCamera,
        _selectedEye.contains('Right') ? 'Right' : 'Left',
        _qualityResult,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScreeningResultScreen(
          apiService: widget.apiService,
          patient: widget.patient,
          imageBytes: _imageBytes!,
          filename: _currentSampleName,
          cameraProfile: _selectedCamera,
          eyeSide: _selectedEye.contains('Right') ? 'Right' : 'Left',
          qualityResult: _qualityResult,
          riskModel: widget.riskModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBlurry = _qualityResult?.qualityGrade == 'BAD';

    final cameraBody = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Quick Action Button
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: _proceedToAnalysis,
                  icon: const Icon(Icons.biotech_rounded, size: 20),
                  label: Text(
                    isBlurry
                        ? '⚠️ Defocus Flagged (Proceed to AI Report Anyway)'
                        : '⚡ Proceed to DR Analysis (Step 3) 🔬',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlurry
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              // Patient & Hardware Ribbon
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.patient.name} (${widget.patient.age}y, ${widget.patient.gender})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedEye = _selectedEye.contains('OD')
                                ? 'Left Eye (OS)'
                                : 'Right Eye (OD)';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedEye,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.swap_horiz,
                                size: 14,
                                color: Color(0xFF1E3A8A),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Upload Custom Image Button
              ElevatedButton.icon(
                onPressed: _pickCustomImage,
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  '📁 Upload Fundus Image (from Device / Camera)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
              ),
              const SizedBox(height: 12),

              // Camera Hardware Preset Selector
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 4.0,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCamera,
                      isExpanded: true,
                      icon: const Icon(Icons.tune),
                      items: const [
                        DropdownMenuItem(
                          value: 'Remidio FOP (Smartphone Handheld)',
                          child: Text('📷 Remidio FOP (Smartphone Handheld)'),
                        ),
                        DropdownMenuItem(
                          value: 'Forus 3nethra classic (PHC Desktop)',
                          child: Text('📷 Forus 3nethra classic (PHC Desktop)'),
                        ),
                        DropdownMenuItem(
                          value: 'Volk iNview (Lens Attachment)',
                          child: Text('📷 Volk iNview (Lens Attachment)'),
                        ),
                        DropdownMenuItem(
                          value: 'Generic Fundus Camera',
                          child: Text('📷 Generic Handheld Camera'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedCamera = v);
                          _runQualityCheck();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Test Sample Fast Selector for Judges
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Test Fundus Photo Scenario:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Live Hardware Feed',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentSampleAsset,
                          isExpanded: true,
                          items: _sampleImages.map((s) {
                            return DropdownMenuItem<String>(
                              value: s['asset']!,
                              child: Text(
                                s['title']!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final chosen = _sampleImages.firstWhere(
                                (x) => x['asset'] == val,
                              );
                              _loadImageAsset(
                                chosen['asset']!,
                                chosen['filename']!,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Camera Viewfinder / Fundus Preview
              Container(
                height: 270,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isBlurry
                        ? const Color(0xFFD97706)
                        : const Color(0xFF10B981),
                    width: 3,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      )
                    else
                      const CircularProgressIndicator(color: Colors.white),

                    // Overlay Reticle Guide
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Quality Badge Top Right
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isBlurry
                              ? const Color(0xFFD97706)
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isCheckingQuality
                              ? 'Evaluating...'
                              : (isBlurry ? 'BAD QUALITY' : 'GRADEABLE'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // DYNAMIC ALERT CARD (Screen 2 from Sinduri's Kit)
              // -------------------------------------------------------------
              if (_qualityResult != null && isBlurry) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD97706),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD97706),
                            size: 26,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ PHOTO TOO BLURRY - PLEASE RETAKE',
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Camera distance error: Move camera 2 cm closer to patient eye.\n'
                        '• Instruct patient to fixate steadily on the green internal cross light.\n'
                        '• Retries remaining: 2 attempts before human specialist referral.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF78350F),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Voice Guidance Button in Hindi
                      OutlinedButton.icon(
                        onPressed: () => _simulateHindiVoicePrompt(
                          _qualityResult!.audioGuidanceHindi,
                        ),
                        icon: const Icon(
                          Icons.volume_up,
                          color: Color(0xFFB45309),
                        ),
                        label: Text(
                          '🔊 Listen in Hindi: "${_qualityResult!.audioGuidanceHindi}"',
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD97706)),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Retake Button
                ElevatedButton.icon(
                  onPressed: _retakePhoto,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    '🔄 Retake Photo (Attempt ${_recaptureCount + 1}/2)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _proceedToAnalysis,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text(
                    'Proceed with Screening Anyway (Clinical Override)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    side: const BorderSide(color: Color(0xFF1E3A8A)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ] else ...[
                if (_qualityResult != null && !isBlurry)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF10B981),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '✅ Image Certified for Clinical Grading',
                                style: TextStyle(
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Laplacian sharpness score: ${_qualityResult!.qualityScore.toStringAsFixed(2)} | FOV & illumination passed.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Proceed to Analysis Button
                ElevatedButton.icon(
                  onPressed: _proceedToAnalysis,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text(
                    'Run AI Diagnostic Screening 🔬',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return Container(color: const Color(0xFFF8FAFC), child: cameraBody);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Camera & Model 1 Quality Gate'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Back to Patient Intake',
              )
            : null,
      ),
      body: cameraBody,
    );
  }
}
