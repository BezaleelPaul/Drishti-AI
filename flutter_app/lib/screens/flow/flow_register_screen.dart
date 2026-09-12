import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../models/screening_models.dart';
import '../../services/api_service.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_capture_screen.dart';
import 'flow_state.dart';

/// Figma "Patient Registration" (Workflow step 1).
/// Empty-by-default fields (no demo PHI ships); registers via backend,
/// evaluates upstream risk, then opens the capture step.
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
  final _duration = TextEditingController();
  final _eyeHistory = TextEditingController();
  String _gender = 'Female';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _patientId.dispose();
    _age.dispose();
    _phone.dispose();
    _village.dispose();
    _duration.dispose();
    _eyeHistory.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final age = int.parse(_age.text.trim());
      final years =
          double.tryParse(_duration.text.trim().split(' ').first) ?? 5.0;
      final patient = PatientModel(
        patientId: _patientId.text.trim().isEmpty
            ? 'PT-${DateTime.now().millisecondsSinceEpoch}'
            : _patientId.text.trim(),
        name: _name.text.trim(),
        age: age,
        gender: _gender,
        phone: _phone.text.trim(),
        abhaId: '',
        village: _village.text.trim(),
        knownDiabetes: 'Yes',
        diabetesDurationYears: years,
        familyHistory: false,
      );
      final risk = await _api.evaluateDiabetesRisk(
        age: age,
        gender: _gender,
        bmi: 25.0,
        familyHistory: false,
        knownDiabetesYears: years,
      );
      // Best-effort registration; offline queue keeps the flow moving.
      await _api.registerPatient(patient).catchError((_) => patient.patientId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlowCaptureScreen(
            state: FlowState(patient: patient, risk: risk),
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
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        title: Text(
          context.tr('reg_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
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
                  const WorkflowBar(step: 1),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('reg_subtitle'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: FigmaColors.muted,
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
                            decoration: _deco(context, 'gender'),
                            items: const ['Female', 'Male', 'Other']
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
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
                  ]),
                  const SizedBox(height: 10),
                  _card(
                    context,
                    '${context.tr('medical_history')} ${context.tr('optional')}',
                    [
                      _field(
                        context,
                        'diabetes_duration',
                        _duration,
                        hint: '8 years',
                      ),
                      _field(context, 'prev_eye', _eyeHistory),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                      color: FigmaColors.faint,
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

  Widget _card(BuildContext context, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const Divider(height: 16),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
