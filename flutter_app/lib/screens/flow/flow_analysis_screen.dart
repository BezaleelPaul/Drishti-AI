import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../models/screening_models.dart';
import '../../services/api_service.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_result_screen.dart';
import 'flow_state.dart';

/// Figma "AI Screening" (Workflow step 3): animated 5-stage stepper
/// while the real `analyzeRetinaFull` call runs in parallel.
class FlowAnalysisScreen extends StatefulWidget {
  final FlowState state;

  const FlowAnalysisScreen({super.key, required this.state});

  @override
  State<FlowAnalysisScreen> createState() => _FlowAnalysisScreenState();
}

class _FlowAnalysisScreenState extends State<FlowAnalysisScreen> {
  static const _steps = [
    'step_quality',
    'step_retina',
    'step_lesion',
    'step_severity',
    'step_explain',
  ];

  final _api = ApiService();
  int _done = 0;
  Timer? _timer;
  ScreeningAnalysisModel? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (!mounted) return;
      if (_done < _steps.length) {
        setState(() => _done++);
      } else {
        t.cancel();
        _maybeProceed();
      }
    });
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final bytes = widget.state.imageBytes;
      if (bytes == null) throw StateError('No image captured');
      final res = await _api.analyzeRetinaFull(
        imageBytes: bytes,
        patientId: widget.state.patient.patientId,
        eyeSide: widget.state.eyeSide,
        cameraProfile: widget.state.cameraProfile,
        filename: widget.state.filename,
      );
      if (!mounted) return;
      setState(() => _result = res);
      _maybeProceed();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _maybeProceed() {
    if (_result != null && _done >= _steps.length && mounted) {
      widget.state.analysis = _result;
      _timer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FlowResultScreen(state: widget.state),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('ai_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WorkflowBar(step: 3),
                const SizedBox(height: 12),
                Text(
                  context.tr('ai_subtitle'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: FigmaColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (widget.state.imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      widget.state.imageBytes!,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FigmaColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        _stepRow(
                          context.tr(_steps[i]),
                          i < _done,
                          i == _done && _error == null,
                        ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FigmaColors.danger),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analysis unavailable: $_error',
                          style: const TextStyle(
                            fontSize: 12,
                            color: FigmaColors.danger,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  context.tr('ai_disclaimer'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: FigmaColors.faint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepRow(String label, bool done, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          done
              ? const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: FigmaColors.success,
                )
              : active
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.radio_button_unchecked,
                  size: 20,
                  color: FigmaColors.faint,
                ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              color: done
                  ? FigmaColors.success
                  : active
                  ? FigmaColors.text
                  : FigmaColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}
