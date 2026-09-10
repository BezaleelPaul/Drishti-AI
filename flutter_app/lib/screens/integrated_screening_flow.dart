import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/screening_models.dart';
import '../services/api_service.dart';
import 'camera_capture_screen.dart';
import 'patient_checkin_screen.dart';
import 'screening_result_screen.dart';

class IntegratedScreeningFlow extends StatefulWidget {
  final ApiService apiService;
  final bool embedded;

  const IntegratedScreeningFlow({
    super.key,
    required this.apiService,
    this.embedded = false,
  });

  @override
  State<IntegratedScreeningFlow> createState() => _IntegratedScreeningFlowState();
}

class _IntegratedScreeningFlowState extends State<IntegratedScreeningFlow> {
  int _activeStep = 0; // 0: Checkin, 1: Camera, 2: Result

  // Shared Screening State
  late PatientModel _patient;
  DiabetesRiskModel? _riskModel;
  Uint8List? _imageBytes;
  String _filename = '2_clear_eye_normal.jpg';
  String _cameraProfile = 'Remidio FOP (Smartphone Handheld)';
  String _eyeSide = 'Right';
  RetinalQualityModel? _qualityResult;

  @override
  void initState() {
    super.initState();
    _patient = PatientModel(
      patientId: 'PT-ASHA-101',
      name: 'Ramesh Kumar',
      age: 54,
      gender: 'Male',
      phone: '+91 98451 22340',
      abhaId: '91-4521-8890-3321',
      village: 'Shivaji Nagar, PHC Bhor',
      knownDiabetes: 'Yes',
      diabetesDurationYears: 5.0,
      hba1c: 8.2,
      bmi: 28.4,
      familyHistory: true,
    );
    _loadDefaultImage();
  }

  Future<void> _loadDefaultImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/2_clear_eye_normal.jpg');
      if (mounted) {
        setState(() {
          _imageBytes = data.buffer.asUint8List();
        });
      }
    } catch (e) {
      debugPrint('Could not pre-load default fundus image: $e');
    }
  }

  void _onProceedFromCheckin(PatientModel patient, DiabetesRiskModel? risk) {
    setState(() {
      _patient = patient;
      _riskModel = risk;
      _activeStep = 1; // Move to Camera
    });
  }

  void _onProceedFromCamera(
    Uint8List imageBytes,
    String filename,
    String cameraProfile,
    String eyeSide,
    RetinalQualityModel? qualityResult,
  ) {
    setState(() {
      _imageBytes = imageBytes;
      _filename = filename;
      _cameraProfile = cameraProfile;
      _eyeSide = eyeSide;
      _qualityResult = qualityResult;
      _activeStep = 2; // Move to Results
    });
  }

  void _onResetFlow() {
    setState(() {
      _activeStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1E3A8A),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _buildStepPill(0, '1. Patient Intake', Icons.person_add_rounded),
                const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                _buildStepPill(1, '2. Quality Gate', Icons.camera_alt_rounded),
                const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                _buildStepPill(2, '3. AI Report', Icons.science_rounded),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _activeStep,
            children: [
              // Step 1: Patient Checkin
              PatientCheckinScreen(
                apiService: widget.apiService,
                onProceedToScan: _onProceedFromCheckin,
                embedded: true,
              ),

              // Step 2: Camera & Quality Gate
              CameraCaptureScreen(
                apiService: widget.apiService,
                patient: _patient,
                riskModel: _riskModel,
                onProceedToAnalysis: _onProceedFromCamera,
                onBack: () => setState(() => _activeStep = 0),
                embedded: true,
              ),

              // Step 3: Screening Results & Grad-CAM
              if (_imageBytes != null)
                ScreeningResultScreen(
                  apiService: widget.apiService,
                  patient: _patient,
                  imageBytes: _imageBytes!,
                  filename: _filename,
                  cameraProfile: _cameraProfile,
                  eyeSide: _eyeSide,
                  qualityResult: _qualityResult,
                  riskModel: _riskModel,
                  onDone: _onResetFlow,
                  embedded: true,
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'Please capture or select an eye photo in Step 2 first.',
                        style: TextStyle(color: Colors.black54, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _activeStep = 1),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                        child: const Text('Go to Step 2: Camera Gate', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Step Navigation Floating Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_activeStep > 0)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _activeStep--),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(
                      _activeStep == 1 ? 'Step 1: Patient Intake' : 'Step 2: Quality Gate',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  'Step ${_activeStep + 1} of 3',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                ),
                if (_activeStep < 2)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _activeStep++),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      _activeStep == 0 ? 'Next: Quality Gate 📸' : 'Next: AI Report 🔬',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _onResetFlow,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('New Screening 🔄', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepPill(int stepIndex, String title, IconData icon) {
    final isActive = _activeStep == stepIndex;
    final isDone = _activeStep > stepIndex;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () {
            setState(() {
              _activeStep = stepIndex;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2563EB)
                  : (isDone ? const Color(0xFF1E3A8A) : Colors.transparent),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? Colors.white : Colors.white24,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDone ? Icons.check_circle : icon,
                  size: 15,
                  color: isActive || isDone ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive || isDone ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
