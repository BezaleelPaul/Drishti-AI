import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../models/retinal_markers.dart';
import '../../models/screening_models.dart' as ui;
import '../../services/ml/pipeline/structure_segmenter.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/orbit/orbit.dart';
import '../../widgets/review/gradcam_explanation_card.dart';
import '../../widgets/review/zoomable_fundus_screen.dart';
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

  RetinalMarkers? _markers;
  bool _markersLoading = false;

  @override
  void initState() {
    super.initState();
    _markers = widget.state.markers;
    if (_markers == null) _loadMarkers();
  }

  /// Computes classical-CV landmark markers off the UI thread. Advisory
  /// only — never gates the grade and never fabricates a landmark.
  Future<void> _loadMarkers() async {
    final bytes = widget.state.imageBytes;
    if (bytes == null) return;
    setState(() => _markersLoading = true);
    try {
      final markers = await compute(computeRetinalMarkers, bytes);
      if (!mounted) return;
      widget.state.markers = markers;
      setState(() => _markers = markers);
    } catch (_) {
      if (!mounted) return;
      setState(() => _markers = null);
    } finally {
      if (mounted) setState(() => _markersLoading = false);
    }
  }

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

  void _openInspector() {
    final bytes = widget.state.imageBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ZoomableFundusScreen(
          imageBytes: bytes,
          title: 'Fundus inspection',
          caption: 'Inspect the original capture · pinch, drag, double-tap',
          markers: _markers,
        ),
      ),
    );
  }

  /// Landmark marker status card. Honest provenance: coordinates come from
  /// classical CV segmentation computed on-device — they are structural
  /// landmarks and lesion CANDIDATES, never model attention or a diagnosis.
  Widget _markerCard() {
    Widget body;
    if (_markersLoading) {
      body = Row(
        children: const [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Locating landmarks (optic disc, fovea, lesion candidates)…',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      );
    } else {
      final markers = _markers;
      if (markers == null || !markers.available) {
        body = Text(
          markers?.reason ?? 'Landmark markers are unavailable for this image.',
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        );
      } else {
        final count = markers.maCandidates.length;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 0
                  ? 'Optic disc & fovea located. No lesion candidates found '
                        '(classical CV — a clear frame can be healthy).'
                  : 'Optic disc, fovea and $count lesion candidate${count == 1 ? '' : 's'} '
                        'located (classical CV segmentation).',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('view_markers_arrows'),
                onPressed: _openInspector,
                icon: const Icon(Icons.arrow_outward, size: 14),
                label: const Text(
                  'View with arrows',
                  style: TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: ScannerHUDTheme.neonCyan,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ),
          ],
        );
      }
    }
    return Container(
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
            Icons.my_location,
            size: 16,
            color: ScannerHUDTheme.neonCyan,
          ),
          const SizedBox(width: 8),
          Expanded(child: body),
        ],
      ),
    );
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('original_fundus'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: widget.state.imageBytes == null
                                ? null
                                : _openInspector,
                            icon: const Icon(Icons.zoom_in, size: 16),
                            label: const Text('Inspect & zoom'),
                            style: TextButton.styleFrom(
                              foregroundColor: ScannerHUDTheme.neonCyan,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Pinch to zoom · open full-screen for detail',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GradcamExplanationCard(analysis: a),
                      const SizedBox(height: 8),
                      _markerCard(),
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
