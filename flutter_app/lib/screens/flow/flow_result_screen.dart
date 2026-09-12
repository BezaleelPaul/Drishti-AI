import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_specialist_screen.dart';
import 'flow_state.dart';

/// Figma "AI Screening Result" (Workflow step 3):
/// severity scale, findings, explainability toggle.
class FlowResultScreen extends StatefulWidget {
  final FlowState state;

  const FlowResultScreen({super.key, required this.state});

  @override
  State<FlowResultScreen> createState() => _FlowResultScreenState();
}

class _FlowResultScreenState extends State<FlowResultScreen> {
  bool _heatmap = true;

  static const _sevKeys = [
    'sev_no_dr',
    'sev_mild',
    'sev_moderate',
    'sev_severe',
    'sev_pdr',
  ];
  static const _sevColors = [
    FigmaColors.success,
    Color(0xFF2563EB),
    FigmaColors.warning,
    Color(0xFFEA580C),
    FigmaColors.danger,
  ];

  @override
  Widget build(BuildContext context) {
    final pending = widget.state.analysis == null;
    if (pending) {
      return Scaffold(
        backgroundColor: FigmaColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: FigmaColors.primaryDark,
          elevation: 1,
          title: Text(
            context.tr('ai_result_title'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Center(
          child: Text(
            context.tr('awaiting_verif'),
            style: const TextStyle(color: FigmaColors.warning),
          ),
        ),
      );
    }
    final a = widget.state.analysis!;
    final grade = a.drGrade ?? 0;
    final ungraded = a.drGrade == null;
    final idx = grade.clamp(0, 4);
    final conf = a.predictionScore != null
        ? '${(a.predictionScore! * 100).toStringAsFixed(1)}%'
        : '—';
    final ma = (a.biomarkers?['microaneurysm_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('ai_result_title'),
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
                // Result card
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
                      const StatusBadge(status: FigmaStatus.awaitingSpecialist),
                      const SizedBox(height: 8),
                      Text(
                        ungraded
                            ? context.tr('awaiting_verif')
                            : '${context.tr('ai_detected')}: ${context.tr(_sevKeys[idx])}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ungraded
                              ? FigmaColors.warning
                              : _sevColors[idx],
                        ),
                      ),
                      Text(
                        '${context.tr('confidence')}: $conf',
                        style: const TextStyle(
                          fontSize: 12,
                          color: FigmaColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('severity_scale'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FigmaColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 0; i < 5; i++)
                            Expanded(
                              child: Container(
                                height: 10,
                                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                                decoration: BoxDecoration(
                                  color: !ungraded && i <= idx
                                      ? _sevColors[idx]
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('sev_no_dr'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: FigmaColors.faint,
                            ),
                          ),
                          Text(
                            context.tr('sev_pdr'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: FigmaColors.faint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${context.tr('risk_level')} ${(a.isReferable ?? false) ? context.tr('badge_referral') : context.tr('sev_moderate')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Findings
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
                        context.tr('ai_findings'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (ma > 0 || grade >= 1)
                        _finding(context.tr('finding_ma'), '$ma'),
                      if (grade >= 2) ...[
                        _finding(context.tr('finding_hm'), '✓'),
                        _finding(context.tr('finding_ex'), '✓'),
                      ],
                      _finding(context.tr('finding_iq'), a.qualityGrade),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Explainability
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('xai_label'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Switch(
                            value: _heatmap,
                            activeThumbColor: FigmaColors.primary,
                            onChanged: (v) => setState(() => _heatmap = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (widget.state.imageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.memory(
                                widget.state.imageBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                              if (_heatmap)
                                Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.8,
                                      colors: [
                                        Colors.red.withValues(alpha: 0.40),
                                        Colors.amber.withValues(alpha: 0.25),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Text(
                        _heatmap
                            ? context.tr('ai_attn')
                            : context.tr('original_fundus'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        context.tr('heatmap_caption'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${context.tr('ai_note_label')} ${context.tr('ai_note_text')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: FigmaColors.faint,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FlowSpecialistScreen(state: widget.state),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    context.tr('btn_proceed_specialist'),
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

  Widget _finding(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 15, color: FigmaColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: FigmaColors.text),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FigmaColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
