import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/lang_scope.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_state.dart';

/// Figma "Screening Report" (Workflow step 5): printable summary,
/// copy-to-clipboard export, restart. Clearly marked demo report.
class FlowReportScreen extends StatefulWidget {
  final FlowState state;

  const FlowReportScreen({super.key, required this.state});

  @override
  State<FlowReportScreen> createState() => _FlowReportScreenState();
}

class _FlowReportScreenState extends State<FlowReportScreen> {
  bool _more = false;

  String _summary(BuildContext context) {
    final st = widget.state;
    final a = st.analysis;
    return [
      context.tr('report_header'),
      '${st.patient.name} (${st.patient.age}y, ${st.patient.gender})',
      '${context.tr('patient_id')}: ${st.patient.patientId}',
      '${context.tr('col_ai_result')}: ${a?.drLabel ?? context.tr('awaiting_verif')}',
      '${context.tr('sev_label')}: Grade ${st.correctedGrade ?? a?.drGrade ?? '-'}',
      '${context.tr('recommended_action')}: ${a?.actionRecommendation ?? ''}',
    ].join('\n');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _summary(context)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('sync_complete'))));
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final a = st.analysis;
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('report_title'),
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
                const WorkflowBar(step: 5),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FigmaColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('report_header'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: FigmaColors.text,
                        ),
                      ),
                      Text(
                        context.tr('demo_report'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.warning,
                        ),
                      ),
                      const Divider(height: 20),
                      _row(
                        context.tr('patient_details'),
                        '${st.patient.name}, ${st.patient.age}y ${st.patient.gender}',
                      ),
                      _row(context.tr('patient_id'), st.patient.patientId),
                      _row(
                        context.tr('col_ai_result'),
                        a?.drLabel ?? context.tr('awaiting_verif'),
                      ),
                      _row(
                        context.tr('key_findings'),
                        a?.plainLanguageAdvice ?? '',
                      ),
                      _row(
                        context.tr('grad_cam'),
                        a?.gradcamOverlayUrl != null ? '✓' : '—',
                      ),
                      _row(
                        context.tr('sp_verified'),
                        context.tr('verified_msg'),
                      ),
                      _row(
                        context.tr('recommended_action'),
                        a?.actionRecommendation ?? '',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    '${context.tr('btn_download')} (Demo)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${context.tr('btn_sms')} (Demo)')),
                  ),
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: Text('${context.tr('btn_sms')} (Demo)'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _more = !_more),
                  child: Text(context.tr(_more ? 'btn_hide' : 'btn_more')),
                ),
                if (_more)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${context.tr('technical_export')}: ${a?.screeningId ?? '-'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: FigmaColors.muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FigmaColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    context.tr('btn_new_screening'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FigmaColors.muted,
            ),
          ),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 13, color: FigmaColors.text),
          ),
        ],
      ),
    );
  }
}
