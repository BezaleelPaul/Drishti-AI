import 'package:flutter/material.dart';
import '../models/screening_models.dart';
import '../services/api_service.dart';
import 'camera_capture_screen.dart';

class PatientCheckinScreen extends StatefulWidget {
  final ApiService apiService;
  final void Function(PatientModel patient, DiabetesRiskModel? risk)? onProceedToScan;

  final bool embedded;

  const PatientCheckinScreen({
    super.key,
    required this.apiService,
    this.onProceedToScan,
    this.embedded = false,
  });

  @override
  State<PatientCheckinScreen> createState() => _PatientCheckinScreenState();
}

class _PatientCheckinScreenState extends State<PatientCheckinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Ramesh Kumar');
  final _ageController = TextEditingController(text: '54');
  final _phoneController = TextEditingController(text: '+91 98451 22340');
  final _abhaController = TextEditingController(text: '91-4521-8890-3321');
  final _villageController = TextEditingController(text: 'Shivaji Nagar, PHC Bhor');
  final _bmiController = TextEditingController(text: '28.4');
  final _hba1cController = TextEditingController(text: '8.2');

  String _gender = 'Male';
  String _diabetesCategory = '5-10 yrs';
  bool _familyHistory = true;
  DiabetesRiskModel? _riskAssessment;

  @override
  void initState() {
    super.initState();
    _evaluateRisk();
  }

  void _loadPreset(String preset) {
    setState(() {
      if (preset == 'ramesh') {
        _nameController.text = 'Ramesh Kumar';
        _ageController.text = '54';
        _phoneController.text = '+91 98451 22340';
        _abhaController.text = '91-4521-8890-3321';
        _villageController.text = 'Shivaji Nagar, PHC Bhor';
        _bmiController.text = '28.4';
        _hba1cController.text = '8.2';
        _gender = 'Male';
        _diabetesCategory = '5-10 yrs';
        _familyHistory = true;
      } else {
        _nameController.text = 'Sunita Devi';
        _ageController.text = '48';
        _phoneController.text = '+91 97120 44510';
        _abhaController.text = '91-8812-3341-9920';
        _villageController.text = 'Wadgaon, PHC Bhor';
        _bmiController.text = '23.8';
        _hba1cController.text = '5.9';
        _gender = 'Female';
        _diabetesCategory = '< 5 yrs';
        _familyHistory = false;
      }
    });
    _evaluateRisk();
  }

  Future<void> _evaluateRisk() async {
    final age = int.tryParse(_ageController.text) ?? 50;
    final bmi = double.tryParse(_bmiController.text) ?? 25.0;
    final hba1c = double.tryParse(_hba1cController.text);
    double years = 5.0;
    if (_diabetesCategory == '< 5 yrs') years = 2.0;
    if (_diabetesCategory == '> 10 yrs') years = 12.0;

    final risk = await widget.apiService.evaluateDiabetesRisk(
      age: age,
      gender: _gender,
      bmi: bmi,
      familyHistory: _familyHistory,
      knownDiabetesYears: years,
      hba1c: hba1c,
      fastingGlucose: null,
    );

    if (mounted) {
      setState(() {
        _riskAssessment = risk;
      });
    }
  }

  void _proceedToEyeScan() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Ramesh Kumar';
    final age = int.tryParse(_ageController.text.trim()) ?? 54;
    final phone = _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : '+91 98451 22340';
    final abha = _abhaController.text.trim().isNotEmpty
        ? _abhaController.text.trim()
        : '91-4521-8890-3321';
    final village = _villageController.text.trim().isNotEmpty
        ? _villageController.text.trim()
        : 'Shivaji Nagar, PHC Bhor';

    double years = 5.0;
    if (_diabetesCategory == '< 5 yrs') years = 2.0;
    if (_diabetesCategory == '> 10 yrs') years = 12.0;

    final patient = PatientModel(
      patientId: 'PT-ASHA-${DateTime.now().millisecondsSinceEpoch % 100000}',
      name: name,
      age: age,
      gender: _gender,
      phone: phone,
      abhaId: abha,
      village: village,
      knownDiabetes: 'Yes',
      diabetesDurationYears: years,
      hba1c: double.tryParse(_hba1cController.text.trim()) ?? 8.2,
      bmi: double.tryParse(_bmiController.text.trim()) ?? 28.4,
      familyHistory: _familyHistory,
    );

    // Register asynchronously in the background so screen transition is instantaneous
    widget.apiService.registerPatient(patient).catchError((_) => patient);

    // Provide immediate visual feedback to the healthcare worker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📸 Opening Eye Scan & Model 1 Quality Gate for ${patient.name}...'),
        duration: const Duration(milliseconds: 1000),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
    );

    if (widget.onProceedToScan != null) {
      widget.onProceedToScan!(patient, _riskAssessment);
      return;
    }

    // Immediate navigation to Eye Scan screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraCaptureScreen(
          apiService: widget.apiService,
          patient: patient,
          riskModel: _riskAssessment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formBody = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Proceed Button at top of form
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: _proceedToEyeScan,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: const Text(
                      '⚡ Proceed to Eye Scan (Step 2) 📸',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                ),
                // Header Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFDBEAFE),
                            child: Icon(Icons.person_add, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Step 1: Patient Check-In',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Ayushman Bharat Digital Mission (ABDM)',
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick Demo Presets Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFF1E3A8A), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Fast Presets:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.person, size: 16, color: Colors.white),
                            label: const Text('Ramesh (High Risk)', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFDC2626),
                            onPressed: () => _loadPreset('ramesh'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.person_outline, size: 16, color: Colors.white),
                            label: const Text('Sunita (Low Risk)', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFF059669),
                            onPressed: () => _loadPreset('sunita'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Form Fields Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Patient Full Name',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age',
                                prefixIcon: Icon(Icons.cake_outlined),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _evaluateRisk(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(_gender),
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (v) {
                                setState(() => _gender = v!);
                                _evaluateRisk();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _abhaController,
                        decoration: const InputDecoration(
                          labelText: 'Ayushman Card (ABHA ID)',
                          prefixIcon: Icon(Icons.credit_card),
                          hintText: '91-XXXX-XXXX-XXXX',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Patient Mobile (for SMS Slip)',
                          prefixIcon: Icon(Icons.phone_android),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _villageController,
                        decoration: const InputDecoration(
                          labelText: 'Village / Primary Health Centre',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Diabetes History Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Diabetes History & Glycemic Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text('Known Duration of Diabetes:'),
                      const SizedBox(height: 8),
                      Row(
                        children: ['< 5 yrs', '5-10 yrs', '> 10 yrs'].map((cat) {
                          final isSelected = _diabetesCategory == cat;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: const Color(0xFF1E3A8A),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (_) {
                                  setState(() => _diabetesCategory = cat);
                                  _evaluateRisk();
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bmiController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'BMI (kg/m²)',
                                hintText: '28.4',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _evaluateRisk(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _hba1cController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'HbA1c (%)',
                                hintText: '8.2',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _evaluateRisk(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Upstream Clinical Risk Badge
              if (_riskAssessment != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _riskAssessment!.riskLevel == 'HIGH'
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _riskAssessment!.riskLevel == 'HIGH'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF10B981),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _riskAssessment!.riskLevel == 'HIGH'
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: _riskAssessment!.riskLevel == 'HIGH'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF10B981),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ICMR Risk: ${_riskAssessment!.riskLevel} (${_riskAssessment!.riskScore.toStringAsFixed(0)}/100)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _riskAssessment!.riskLevel == 'HIGH'
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF047857),
                              ),
                            ),
                            Text(
                              _riskAssessment!.patientFriendlyGuidance,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Start Eye Scan Action Button
              ElevatedButton(
                onPressed: _proceedToEyeScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera_alt_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Start Eye Scan 📸',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
                const SizedBox(height: 16),
                // Inline primary button at bottom of form
                ElevatedButton.icon(
                  onPressed: _proceedToEyeScan,
                  icon: const Icon(Icons.camera_alt_rounded, size: 22),
                  label: const Text(
                    'Start Eye Scan 📸 (Next Step: Quality Gate)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: formBody,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Netra-AI Rural Health Screening'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            tooltip: 'Fast Demo Presets',
            onSelected: _loadPreset,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'ramesh',
                child: Text('Preset: Ramesh Kumar (High Risk)'),
              ),
              const PopupMenuItem(
                value: 'sunita',
                child: Text('Preset: Sunita Devi (Low Risk)'),
              ),
            ],
          ),
        ],
      ),
      body: formBody,
    );
}
}
