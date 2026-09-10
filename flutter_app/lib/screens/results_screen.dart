import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/patient.dart';
import '../models/screening.dart';
import '../services/api_service.dart';
import 'checkin_screen.dart';

class ResultsScreen extends StatefulWidget {
  final Patient patient;
  final String eyeSide;
  final String cameraProfile;
  final String assetImagePath;

  const ResultsScreen({
    super.key,
    required this.patient,
    required this.eyeSide,
    required this.cameraProfile,
    required this.assetImagePath,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  ScreeningResult? _result;

  // Biomarkers from the server (null = ungradable / unavailable — shown as N/A)
  double? _vesselDensity;
  String? _csmeRisk;
  int? _hemorrhageCount;
  double? _aiLatency;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _performScreening();
  }

  Future<void> _performScreening() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });
    try {
      final byteData = await rootBundle.load(widget.assetImagePath);
      final bytes = byteData.buffer.asUint8List();

      final t0 = DateTime.now();
      final res = await _apiService.analyzeRetina(
        imageBytes: bytes,
        patientId: widget.patient.patientId,
        eyeSide: widget.eyeSide,
        cameraProfile: widget.cameraProfile,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _result = res;
        // Server-measured biomarkers only — null stays null (rendered as N/A).
        _vesselDensity = res.vesselDensityPct;
        _csmeRisk = res.csmeRisk;
        _hemorrhageCount = res.microaneurysmCount;
        _aiLatency = DateTime.now().difference(t0).inMilliseconds / 1000.0;
      });
    } catch (e) {
      // Honest error state: no diagnosis is shown without a server result.
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _result = null;
        _errorMessage = 'Analysis unavailable: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic Triage')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Running server-side quality gate + DR grading...', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Includes Grad-CAM++ explainability overlay', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic Triage')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                const Text('Analysis unavailable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage ?? 'No result returned by the server.',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                const Text('No diagnosis is shown without a verified server result.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: _performScreening,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final res = _result!;
    // Defense in depth: if the image failed the quality gate, no grade may
    // be shown — even if a dr_grade somehow arrives with the payload.
    final gradeLeaked = !res.qualityPassed && res.drGrade != null;
    final isPending = res.drGrade == null || gradeLeaked;
    final isReferable = !isPending && res.isReferable == true;
    final drGradeLabel = isPending ? 'PENDING' : '${res.drGrade}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Diagnostic Report (${widget.patient.name})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Verdict Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPending ? const Color(0xFFFFFBEB) : (isReferable ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPending ? Colors.amber.shade600 : (isReferable ? const Color(0xFFF87171) : Colors.green.shade400),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPending ? Icons.hourglass_top : (isReferable ? Icons.crisis_alert : Icons.check_circle),
                          color: isPending ? Colors.amber.shade800 : (isReferable ? Colors.red.shade700 : Colors.green.shade700),
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPending ? 'ANALYSIS PENDING — NO GRADE ASSIGNED' : (isReferable ? 'URGENT SPECIALIST REFERRAL' : 'HEALTHY RETINA — NO DR'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPending ? Colors.amber.shade900 : (isReferable ? Colors.red.shade900 : Colors.green.shade900),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (gradeLeaked)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB45309)),
                        ),
                        child: const Text(
                          'Image failed the quality gate — grade withheld. Retake the photograph; do not act on any grade for this image.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    if (gradeLeaked) const SizedBox(height: 6),
                    Text(
                      isPending ? 'GRADE: PENDING (image queued for server analysis)' : 'GRADE $drGradeLabel: ${res.drLabel?.toUpperCase() ?? "UNKNOWN"}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isReferable ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${res.predictionScore != null ? "Confidence: ${(res.predictionScore! * 100).toStringAsFixed(1)}% • " : ""}${widget.eyeSide} Eye (${widget.cameraProfile})',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      res.capturedAt != null && res.capturedAt!.isNotEmpty
                          ? 'Captured in field: ${res.capturedAt}'
                          : 'Captured: ${res.createdAt}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const Divider(height: 16),
                    Text(
                      res.actionRecommendation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPending ? Colors.amber.shade900 : (isReferable ? Colors.red.shade900 : Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Retinal Inspection Split View
              const Text('Visual Explainability Inspection (Grad-CAM++)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Original Fundus', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            widget.assetImagePath,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(height: 150, color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Grad-CAM++ Attention', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                widget.assetImagePath,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(height: 150, color: Colors.grey.shade300),
                              ),
                              // Heatmap overlay simulation
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.8,
                                    colors: isReferable
                                        ? [Colors.red.withOpacity(0.65), Colors.orange.withOpacity(0.3), Colors.transparent]
                                        : [Colors.blue.withOpacity(0.3), Colors.transparent],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Illustrative overlay*', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text('*On-device illustration only — the verified Grad-CAM++ heatmap is served with the server result.',
                    style: TextStyle(fontSize: 10, color: Colors.black45)),
              ),
              const SizedBox(height: 16),

              // 2x2 Biomarker Grid
              const Text('Extracted Clinical Biomarkers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildBiomarkerTile('Vessel Density', _vesselDensity != null ? '$_vesselDensity%' : 'N/A', 'Normal: 12-16%', Icons.timeline)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildBiomarkerTile('CSME Edema Risk', _csmeRisk?.split(' ').first ?? 'N/A', 'ETDRS <500µm Rule', Icons.remove_red_eye)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildBiomarkerTile('Lesion / MA Count', _hemorrhageCount?.toString() ?? 'N/A', 'Sub-pixel morphology', Icons.scatter_plot)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildBiomarkerTile('Total Wait', _aiLatency != null ? '${_aiLatency!.toStringAsFixed(1)}s' : 'N/A', 'Request round-trip', Icons.speed)),
                ],
              ),
              const SizedBox(height: 18),

              // Action Hub Buttons
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.sms),
                label: const Text('📲 Send Free SMS Referral Slip to Patient'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Demo build: SMS not sent. Server referral slip: ${res.actionRecommendation}')),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print),
                label: const Text('🖨️ Print 2-Inch Thermal Receipt'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo build: no printer connected. Use the server PDF for print.')),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('📄 Export ABDM FHIR R4 Bundle'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo build: FHIR export runs on the server, not on-device.')),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Next Patient Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.person_add),
                label: const Text('Start Next Patient Screen ➕', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const CheckInScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiomarkerTile(String title, String value, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF1A56DB)),
              const SizedBox(width: 4),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ],
      ),
    );
  }
}
