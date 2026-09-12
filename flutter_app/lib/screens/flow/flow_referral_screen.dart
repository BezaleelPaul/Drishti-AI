import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_report_screen.dart';
import 'flow_state.dart';

/// Figma "Referral" (Workflow step 4): urgency card, specialist,
/// send actions. SMS has no backend endpoint — labelled Demo, honest.
class FlowReferralScreen extends StatefulWidget {
  final FlowState state;

  const FlowReferralScreen({super.key, required this.state});

  @override
  State<FlowReferralScreen> createState() => _FlowReferralScreenState();
}

class _FlowReferralScreenState extends State<FlowReferralScreen> {
  bool _smsSent = false;

  void _sendSms() {
    setState(() => _smsSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.tr('btn_send_sms')} (Demo): ${widget.state.patient.phone}',
        ),
        backgroundColor: FigmaColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final grade = st.correctedGrade ?? st.analysis?.drGrade ?? 2;
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('referral_title'),
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
                const WorkflowBar(step: 4),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FigmaColors.danger),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('referral_required'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: FigmaColors.danger,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${context.tr('sev_label')}: Grade $grade',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.text,
                        ),
                      ),
                      Text(
                        '${context.tr('urgency_label')}: 4 weeks',
                        style: const TextStyle(
                          fontSize: 13,
                          color: FigmaColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('referral_msg'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: FigmaColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
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
                        context.tr('recommended_specialist'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'District Eye Care Centre — Retina & Vitreous Clinic',
                        style: TextStyle(
                          fontSize: 12,
                          color: FigmaColors.muted,
                        ),
                      ),
                      Text(
                        '${st.patient.name} • ${st.patient.phone}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: FigmaColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: st.referralSent
                      ? null
                      : () => setState(() => st.referralSent = true),
                  icon: Icon(
                    st.referralSent ? Icons.check : Icons.send_outlined,
                  ),
                  label: Text(
                    st.referralSent
                        ? context.tr('sync_complete')
                        : context.tr('btn_send_referral'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _smsSent ? null : _sendSms,
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: Text('${context.tr('btn_send_sms')} (Demo)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FlowReportScreen(state: st),
                    ),
                  ),
                  child: Text(context.tr('btn_continue_report')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
