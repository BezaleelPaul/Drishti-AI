import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../models/screening_models.dart';
import '../../services/api_service.dart';
import '../../widgets/scanner/scanner.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_capture_screen.dart';
import 'flow_state.dart';

/// Figma "Patient Registration" (Workflow step 1) — the ONE canonical intake,
/// merged with the Rural Health Screening clinical requirements: 14-digit
/// ABHA number (+ QR-scan affordance), HbA1c (%), blood pressure (mmHg),
/// BMI and diabetes-duration pills. Demo presets exist in debug builds only.
class FlowRegisterScreen extends StatefulWidget {
  const FlowRegisterScreen({super.key});

  @override
  State<FlowRegisterScreen> createState() => _FlowRegisterScreenState();
}

class _FlowRegisterScreenState extends State<FlowRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _name = TextEditingController();
  final _patientId = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _village = TextEditingController();
  final _abha = TextEditingController();
  final _hba1c = TextEditingController();
  final _bp = TextEditingController();
  final _bmi = TextEditingController();
  final _eyeHistory = TextEditingController();
  String _gender = 'Female';
  String _diabetesDuration = '< 5 yrs';
  bool _familyHistory = false;
  bool _busy = false;

  static const _durationPills = ['< 5 yrs', '5-10 yrs', '> 10 yrs'];
  static const _durationYears = {
    '< 5 yrs': 3.0,
    '5-10 yrs': 7.0,
    '> 10 yrs': 12.0,
  };

  @override
  void dispose() {
    _name.dispose();
    _patientId.dispose();
    _age.dispose();
    _phone.dispose();
    _village.dispose();
    _abha.dispose();
    _hba1c.dispose();
    _bp.dispose();
    _bmi.dispose();
    _eyeHistory.dispose();
    super.dispose();
  }

  // ---- Field validators (optional unless required is set) ----

  String? _validateAbha(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // optional — server accepts null
    if (digits.length != 14) return 'ABHA must be 14 digits';
    return null;
  }

  String? _validateHba1c(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null; // optional: not measured
    final h = double.tryParse(text);
    if (h == null) return 'Enter a number (e.g. 8.8)';
    if (h < 3 || h > 20) return 'HbA1c must be 3–20%';
    return null;
  }

  String? _validateBp(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null; // optional: not measured
    if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(text)) {
      return 'Use SYS/DIA format (e.g. 145/90)';
    }
    return null;
  }

  String? _validateBmi(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null; // optional: not measured
    final b = double.tryParse(text);
    if (b == null) return 'Enter a number (e.g. 24.5)';
    if (b < 10 || b > 60) return 'BMI must be 10–60';
    return null;
  }

  /// Debug-only demo presets (never in release builds) — fill the form to
  /// exercise both risk paths without touching production records.
  void _loadPreset(String preset) {
    setState(() {
      if (preset == 'ramesh') {
        _name.text = 'Ramesh Kumar';
        _age.text = '54';
        _phone.text = '+91 98451 22340';
        _abha.text = '91-4521-8890-3321';
        _village.text = 'Shivaji Nagar, PHC Bhor';
        _bmi.text = '28.4';
        _hba1c.text = '8.2';
        _gender = 'Male';
        _diabetesDuration = '5-10 yrs';
        _familyHistory = true;
      } else {
        _name.text = 'Sunita Devi';
        _age.text = '48';
        _phone.text = '+91 97120 44510';
        _abha.text = '91-8812-3341-9920';
        _village.text = 'Wadgaon, PHC Bhor';
        _bmi.text = '23.8';
        _hba1c.text = '5.9';
        _gender = 'Female';
        _diabetesDuration = '< 5 yrs';
        _familyHistory = false;
      }
    });
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final age = int.parse(_age.text.trim());
      final years = _durationYears[_diabetesDuration] ?? 5.0;
      final hba1c = double.tryParse(_hba1c.text.trim());
      final bmi = double.tryParse(_bmi.text.trim());
      final bp = _bp.text.trim();
      final patient = PatientModel(
        patientId: _patientId.text.trim().isEmpty
            ? 'PT-${DateTime.now().millisecondsSinceEpoch}'
            : _patientId.text.trim(),
        name: _name.text.trim(),
        age: age,
        gender: _gender,
        phone: _phone.text.trim(),
        abhaId: _abha.text.trim(),
        village: _village.text.trim(),
        knownDiabetes: 'Yes',
        diabetesDurationYears: years,
        hba1c: hba1c,
        bmi: bmi,
        familyHistory: _familyHistory,
        bloodPressure: bp.isEmpty ? null : bp,
      );
      final risk = await _api.evaluateDiabetesRisk(
        age: age,
        gender: _gender,
        bmi: bmi ?? 25.0,
        familyHistory: _familyHistory,
        knownDiabetesYears: years,
      );
      // Best-effort registration; offline queue keeps the flow moving.
      await _api.registerPatient(patient).catchError((_) => patient.patientId);
      if (!mounted) return;
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlowCaptureScreen(
              state: FlowState(patient: patient, risk: risk),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScannerHUDTheme.background,
      appBar: AppBar(
        backgroundColor: ScannerHUDTheme.darkSurface,
        foregroundColor: ScannerHUDTheme.neonCyan,
        elevation: 0,
        title: Text(
          context.tr('reg_title'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WorkflowBar(step: 1, dark: true),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('reg_subtitle'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(context, context.tr('basic_info'), [
                    _field(context, 'patient_name', _name, required: true),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            context,
                            'patient_id',
                            _patientId,
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            context,
                            'age',
                            _age,
                            required: true,
                            keyboard: TextInputType.number,
                            validator: (v) {
                              final a = int.tryParse((v ?? '').trim());
                              if (a == null || a < 1 || a > 120) {
                                return '1–120';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _gender,
                            dropdownColor: ScannerHUDTheme.darkSurface,
                            decoration: _deco(context, 'gender'),
                            style: const TextStyle(color: Color(0xFFE2E8F0)),
                            items: const ['Female', 'Male', 'Other']
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g,
                                      style: const TextStyle(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _gender = v ?? 'Female'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            context,
                            'phone',
                            _phone,
                            keyboard: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    _field(context, 'village', _village),
                    _literalField(
                      context,
                      '14-digit ABHA Number',
                      _abha,
                      keyboard: TextInputType.number,
                      validator: _validateAbha,
                      qrScanStub: true,
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _card(context, 'Diabetic biomarkers & vitals', [
                    _literalField(
                      context,
                      'HbA1c (%)',
                      _hba1c,
                      validator: _validateHba1c,
                    ),
                    _literalField(
                      context,
                      'Blood Pressure (mmHg)',
                      _bp,
                      hint: '145/90',
                      validator: _validateBp,
                    ),
                    _literalField(
                      context,
                      'BMI (kg/m²)',
                      _bmi,
                      keyboard: TextInputType.number,
                      validator: _validateBmi,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final pill in _durationPills)
                          FilterChip(
                            label: Text(pill),
                            selected: _diabetesDuration == pill,
                            onSelected: (_) =>
                                setState(() => _diabetesDuration = pill),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      value: _familyHistory,
                      onChanged: (v) => setState(() => _familyHistory = v),
                      title: const Text('Family history of diabetes'),
                      subtitle: const Text('First-degree relative'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    _field(context, 'prev_eye', _eyeHistory),
                  ]),
                  const SizedBox(height: 14),
                  if (kDebugMode) ..._debugPresetBanner(),
                  ElevatedButton(
                    onPressed: _busy ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            context.tr('continue_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('privacy_note'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Same input chrome as [_field], with an English literal label for the
  /// merged clinical fields (ABHA / HbA1c / BP / BMI have no l10n keys yet).
  Widget _literalField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? hint,
    String? Function(String?)? validator,
    bool qrScanStub = false,
  }) {
    var deco = _deco(context, label, hint: hint);
    if (qrScanStub) {
      deco = deco.copyWith(
        suffixIcon: IconButton(
          icon: const Icon(
            Icons.qr_code_scanner,
            color: ScannerHUDTheme.neonCyan,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Demo build: QR scan not wired. Verify the ABHA number on the portal before proceeding.',
                ),
              ),
            );
          },
        ),
      );
    }
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Color(0xFFE2E8F0)),
      decoration: deco,
      validator: validator,
    );
  }

  /// Debug-only paste button row ("Fast Presets") ported from the retired
  /// 3-step demo intake — never rendered in release builds.
  List<Widget> _debugPresetBanner() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ScannerHUDTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: ScannerHUDTheme.neonCyan, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Fast Presets (debug):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ScannerHUDTheme.neonCyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text(
                      'Ramesh (High Risk)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: const Color(0xFFDC2626),
                    onPressed: () => _loadPreset('ramesh'),
                  ),
                  ActionChip(
                    label: const Text(
                      'Sunita (Low Risk)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: const Color(0xFF059669),
                    onPressed: () => _loadPreset('sunita'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _card(BuildContext context, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScannerHUDTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const Divider(height: 16, color: Color(0xFF334155)),
          ...children.map(
            (w) =>
                Padding(padding: const EdgeInsets.only(bottom: 10), child: w),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(BuildContext context, String labelKey, {String? hint}) {
    return InputDecoration(
      labelText: context.tr(labelKey),
      hintText: hint,
      filled: true,
      fillColor: ScannerHUDTheme.darkSurface,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ScannerHUDTheme.neonCyan),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    String labelKey,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboard,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Color(0xFFE2E8F0)),
      decoration: _deco(
        context,
        labelKey,
        hint: hint,
      ).copyWith(suffixText: null),
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? '*' : null
              : null),
    );
  }
}
