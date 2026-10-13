import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../models/screening_models.dart' as ui;
import '../../theme/figma_theme.dart';
import '../../widgets/orbit/orbit.dart';
import '../../widgets/scanner/scanner.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_specialist_screen.dart';
import 'flow_state.dart';

/// Figma "AI Screening Result" (Workflow step 3):
/// severity scale, findings, explainability.
///
/// Honest-visibility rules enforced here:
/// - preliminary on-device results are never labeled service-confirmed;
/// - no synthetic "attention" overlay is ever drawn over the fundus;
/// - an explanation section either shows a real model-derived artifact or
///   an explicit unavailable state.
class FlowResultScreen extends StatefulWidget {
  final FlowState state;

  const FlowResultScreen({super.key, required this.state});

  @override
  State<FlowResultScreen> createState() => _FlowResultScreenState();
}

class _FlowResultScreenState extends State<FlowResultScreen> {
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

  /// Honest provenance line (E-2): where the numbers came from and what
  /// they cost. Measured on-device time when available, e.g.
  /// "on-device TFLite, 612 ms" — never a fabricated number.
  String _backendSuffix(ui.ScreeningAnalysisModel a) {
    final backend = a.modelBackend;
    final ms = (a.biomarkers?['inference_time_ms'] as num?)?.toDouble();
    if (backend == null && ms == null) return '';
    final parts = <String>[
      if (backend != null) backend == 'tflite-fp32' ? 'on-device' : backend,
      if (ms != null) '${ms.toStringAsFixed(0)} ms',
    ];
    return parts.isEmpty ? '' : '  •  ${parts.join(" • ")}';
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.state.analysis == null;
    if (pending) {
      return Scaffold(
        backgroundColor: ScannerHUDTheme.background,
        appBar: AppBar(
          backgroundColor: ScannerHUDTheme.darkSurface,
          foregroundColor: ScannerHUDTheme.neonCyan,
          elevation: 0,
          title: Text(
            context.tr('ai_result_title'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
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
    // A terminal error code means the prediction is not a result: never show
    // it as "AI detected X". Exception: a referable grade stays visible
    // because under-referral is the larger clinical risk.
    final errorCode = a.errorCode;
    final isReferable = a.isReferable == true;
    final ungraded = a.drGrade == null || (errorCode != null && !isReferable);
    final provisional = errorCode != null && !ungraded;
    final idx = grade.clamp(0, 4);
    final conf = a.predictionScore != null
        ? '${(a.predictionScore! * 100).toStringAsFixed(1)}%'
        : '—';
    final ma = (a.biomarkers?['microaneurysm_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: ScannerHUDTheme.background,
      appBar: AppBar(
        backgroundColor: ScannerHUDTheme.darkSurface,
        foregroundColor: ScannerHUDTheme.neonCyan,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('ai_result_title'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WorkflowBar(step: 3, dark: true),
                const SizedBox(height: 12),
                // Result card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ScannerHUDTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StatusBadge(status: FigmaStatus.awaitingSpecialist),
                      const SizedBox(height: 8),
                      // Provenance/limitation markers: what this result is
                      // (preliminary) and how it reached us (offline queue).
                      // Backend identity stays in the confidence line below.
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!ungraded)
                            const OrbitChip(
                              label: 'PRELIMINARY',
                              color: Color(0xFFA855F7),
                            ),
                          if (a.isOffline)
                            const OrbitChip(
                              label: 'OFFLINE — PENDING SYNC',
                              color: Color(0xFFF59E0B),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ungraded
                            ? context.tr('awaiting_verif')
                            : '${context.tr('ai_detected')}: ${context.tr(_sevKeys[idx])}'
                                  '${provisional ? ' — provisional, clinician sign-off required' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ungraded
                              ? FigmaColors.warning
                              : _sevColors[idx],
                        ),
                      ),
                      Text(
                        '${context.tr('confidence')}: $conf'
                        '${_backendSuffix(a)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      // Rejection transparency: when the gate refuses an
                      // image the operator must see WHY (reason codes are
                      // the contract — a bare "pending" reads like a bug).
                      if (ungraded && a.rejectionReasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ScannerHUDTheme.darkSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FigmaColors.danger),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rejected — no DR grade assigned '
                                '(${a.errorCode ?? 'IMG_UNGRADABLE'}):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF87171),
                                ),
                              ),
                              for (final reason in a.rejectionReasons)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '• $reason',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        context.tr('severity_scale'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
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
                                      : const Color(0xFF1E293B),
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
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            context.tr('sev_pdr'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
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
                          color: Colors.white,
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
                    color: ScannerHUDTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('ai_findings'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                // Explainability — honest state only: real fundus image plus
                // an explicit unavailable notice (no synthetic overlay).
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('xai_label'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.state.imageBytes != null)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: ScannerView(
                              imageBytes: widget.state.imageBytes,
                              isInteractive: true,
                              state:
                                  a.qualityGrade.toUpperCase() == 'BORDERLINE'
                                  ? ScannerAnimationState.reviewRequired
                                  : ScannerAnimationState.resultReady,
                              customStatusText:
                                  a.qualityGrade.toUpperCase() == 'BORDERLINE'
                                  ? 'REVIEW REQUIRED'
                                  : 'ORIGINAL FUNDUS',
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('original_fundus'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ScannerHUDTheme.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: ScannerHUDTheme.neonCyan,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Explanation unavailable',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'No verified model-derived explanation exists '
                                    'for this result. Attention maps are only '
                                    'shown when generated by the model that '
                                    'produced this grade.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
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
                ),
                const SizedBox(height: 10),
                Text(
                  '${context.tr('ai_note_label')} ${context.tr('ai_note_text')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
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
                    backgroundColor: FigmaColors.primary,
                    foregroundColor: Colors.white,
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
              style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
