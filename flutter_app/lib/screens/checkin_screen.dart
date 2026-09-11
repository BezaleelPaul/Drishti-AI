import 'package:flutter/material.dart';
import 'dart:async';
import '../models/patient.dart';
import 'quality_gate_screen.dart';
import 'queue_screen.dart';
import '../services/api_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  // Empty defaults: demo PHI must never ship as prefilled patient data.
  final _abhaController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController();
  final _hba1cController = TextEditingController();
  final _bpController = TextEditingController();

  String _gender = 'Male';
  String _diabetesDuration = '>10 yrs';
  bool _isRegistering = false;
  bool? _serverReachable;

  @override
  void initState() {
    super.initState();
    unawaited(_apiService.ping().then((ok) {
      if (!mounted) return;
      setState(() => _serverReachable = ok);
    }));
  }

  @override
  void dispose() {
    _abhaController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _hba1cController.dispose();
    _bpController.dispose();
    super.dispose();
  }

  String? _validateAge(String? v) {
    final age = int.tryParse((v ?? '').trim());
    if (age == null) return 'Enter age in years';
    if (age < 1 || age > 120) return 'Age must be 1–120';
    return null;
  }

  String? _validateHba1c(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null; // optional: null means 'not measured', key omitted
    final h = double.tryParse(text);
    if (h == null) return 'Enter a number (e.g. 8.8)';
    if (h < 3 || h > 20) return 'HbA1c must be 3–20%';
    return null;
  }

  String? _validateBp(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null; // optional: omit when not measured
    if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(text)) {
      return 'Use SYS/DIA format (e.g. 145/90)';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter mobile number';
    if (digits.length < 10) return 'Enter a valid 10-digit number';
    return null;
  }

  String? _validateAbha(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // optional — server accepts null
    if (digits.length != 14) return 'ABHA must be 14 digits';
    return null;
  }

  Future<void> _registerAndProceed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isRegistering = true);
    try {
      // Client-side id uses full epoch ms (backend also accepts a null id
      // and generates its own). No modulo truncation — 10k-space ids collide.
      final patient = Patient(
        patientId: 'PT-${DateTime.now().millisecondsSinceEpoch}',
        abhaId: _abhaController.text.trim(),
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _gender,
        phone: _phoneController.text.trim(),
        village: _villageController.text.trim(),
        screeningCentre: 'PHC Shirur Sub-Centre',
        diabetesDurationYears:
            _diabetesDuration == '<5 yrs' ? 3.0 : (_diabetesDuration == '5-10 yrs' ? 7.0 : 12.0),
        hba1c: _hba1cController.text.trim().isEmpty
            ? null
            : double.parse(_hba1cController.text.trim()),
        bloodPressure: _bpController.text.trim(),
      );

      final confirmedId = await _apiService.registerPatient(patient);
      final wasQueued = ApiService.offlinePatients
          .any((p) => '${p['patient_id']}' == patient.patientId);
      if (!mounted) return;
      if (wasQueued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Offline — patient saved on device and will be registered on sync.')),
        );
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QualityGateScreen(
            patient: Patient(
              patientId: confirmedId,
              abhaId: patient.abhaId,
              name: patient.name,
              age: patient.age,
              gender: patient.gender,
              phone: patient.phone,
              village: patient.village,
              screeningCentre: patient.screeningCentre,
              diabetesDurationYears: patient.diabetesDurationYears,
              hba1c: patient.hba1c,
              bloodPressure: patient.bloodPressure,
            ),
          ),
        ),
      );
    } catch (e) {
      // Server rejection (400/401/422...) — stay on the form, show why.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Netra-AI Rural Health Screening',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${ApiService.offlineQueue.length + ApiService.offlinePatients.length}'),
              isLabelVisible: ApiService.offlineQueue.isNotEmpty || ApiService.offlinePatients.isNotEmpty,
              child: const Icon(Icons.sync),
            ),
            tooltip: 'Offline Sync Queue',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QueueScreen()),
              ).then((_) => setState(() {}));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Government Header Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital, color: Color(0xFF1A56DB), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'National Health Mission • Ayushman Bharat',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A56DB)),
                            ),
                            Text(
                              'ASHA Field Worker Portal • Fast Patient Intake',
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _serverReachable == false
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                                _serverReachable == null
                                    ? Icons.sync
                                    : (_serverReachable!
                                        ? Icons.wifi
                                        : Icons.wifi_off),
                                size: 14,
                                color: _serverReachable == false
                                    ? Colors.red
                                    : Colors.green),
                            const SizedBox(width: 4),
                            Text(
                                _serverReachable == null
                                    ? 'Checking…'
                                    : (_serverReachable!
                                        ? 'Server Online'
                                        : 'Offline'),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _serverReachable == false
                                        ? Colors.red
                                        : Colors.green)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card 1: ABHA ID
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Ayushman Bharat (ABHA) Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _abhaController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '14-digit ABHA Number',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF1A56DB)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Demo build: QR scan not wired. Verify the ABHA number on the portal before proceeding.')),
                                );
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: _validateAbha,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Card 2: Patient Demographics
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2. Patient Demographics & Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter name' : null,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Age',
                                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: _validateAge,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _gender,
                                decoration: InputDecoration(
                                  labelText: 'Gender',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Mobile Phone',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _villageController,
                          decoration: InputDecoration(
                            labelText: 'Village / Sub-Centre',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Card 3: Clinical Risk Chips
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('3. Diabetes Duration & Biomarkers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        const Text('Known Diabetes Duration:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: ['<5 yrs', '5-10 yrs', '>10 yrs'].map((duration) {
                            final isSelected = _diabetesDuration == duration;
                            return ChoiceChip(
                              label: Text(duration),
                              selected: isSelected,
                              selectedColor: const Color(0xFF1A56DB),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) => setState(() => _diabetesDuration = duration),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _hba1cController,
                                decoration: InputDecoration(
                                  labelText: 'HbA1c (%)',
                                  suffixText: '%',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: _validateHba1c,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _bpController,
                                decoration: InputDecoration(
                                  labelText: 'BP (mmHg)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: _validateBp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Main CTA Button: Start Eye Scan (registers patient first)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56DB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isRegistering ? null : _registerAndProceed,
                  child: _isRegistering
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Registering patient…',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : const Text(
                          'Start Eye Scan 📸',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
