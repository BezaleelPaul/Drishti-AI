import 'package:flutter/material.dart';
import '../../l10n/lang_scope.dart';
import '../../services/api_service.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_referral_screen.dart';
import 'flow_state.dart';

/// Figma "Specialist Review" (Workflow step 4):
/// why-this-result, confirm / change / re-examine, notes, submit.
class FlowSpecialistScreen extends StatefulWidget {
  final FlowState state;

  const FlowSpecialistScreen({super.key, required this.state});

  @override
  State<FlowSpecialistScreen> createState() => _FlowSpecialistScreenState();
}

class _FlowSpecialistScreenState extends State<FlowSpecialistScreen> {
  final _api = ApiService();
  final _notes = TextEditingController();
  String _decision = 'CONFIRM';
  int _correctedGrade = 2;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  static const _sevKeys = [
    'sev_no_dr',
    'sev_mild_npdr',
    'sev_moderate_npdr',
    'sev_severe_npdr',
    'sev_pdr',
  ];

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      widget.state.verdict = _decision;
      widget.state.correctedGrade = _decision == 'CHANGE'
          ? _correctedGrade
          : null;
      widget.state.specialistNotes = _notes.text.trim();
      // Best-effort server verdict: find the pending review for this
      // screening and record the decision. Offline/unknown → local only.
      try {
        final pending = await _api.getPendingReviews(limit: 100);
        final sid = widget.state.analysis?.screeningId;
        final match = pending.where((r) => '${r['screening_id']}' == '$sid');
        if (match.isNotEmpty) {
          final decision = _decision == 'CHANGE'
              ? 'OVERRIDE_GRADE'
              : _decision == 'REEXAMINE'
              ? 'REQUEST_RECAPTURE'
              : 'CONFIRM';
          await _api.submitDoctorDecision(
            reviewId: '${match.first['review_id']}',
            doctorName: 'Dr. Sharma (MS Ophth)',
            decision: decision,
            clinicalNotes: widget.state.specialistNotes.isEmpty
                ? 'Figma flow specialist verdict: $_decision.'
                : widget.state.specialistNotes,
            gradeOverride: _decision == 'CHANGE' ? _correctedGrade : null,
          );
        }
      } catch (_) {
        // Local verdict stands; sync covers the rest.
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlowReferralScreen(state: widget.state),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.state.analysis;
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        title: Text(
          context.tr('specialist_title'),
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
                // AI result card
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
                        context.tr('ai_result_card'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.text,
                        ),
                      ),
                      if (a != null)
                        Text(
                          '${a.drLabel ?? context.tr('awaiting_verif')}'
                          '${a.predictionScore != null ? ' • ${(a.predictionScore! * 100).toStringAsFixed(1)}%' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: FigmaColors.muted,
                          ),
                        ),
                      const SizedBox(height: 6),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          context.tr('why_result'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: FigmaColors.primaryDark,
                          ),
                        ),
                        children: [
                          Text(
                            context.tr('why_result_text'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: FigmaColors.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('decision_label'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                _decisionCard(
                  'CONFIRM',
                  Icons.check_circle,
                  'confirm_lbl',
                  'confirm_sub',
                ),
                _decisionCard('CHANGE', Icons.tune, 'change_lbl', 'change_sub'),
                _decisionCard(
                  'REEXAMINE',
                  Icons.refresh,
                  'reexamine_lbl',
                  'reexamine_sub',
                ),
                if (_decision == 'CHANGE') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _correctedGrade,
                    decoration: InputDecoration(
                      labelText: context.tr('select_severity'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      for (var i = 0; i < 5; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(context.tr(_sevKeys[i])),
                        ),
                    ],
                    onChanged: (v) => setState(() => _correctedGrade = v ?? 2),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('notes_lbl'),
                    hintText: context.tr('notes_ph'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
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
                          context.tr('btn_verify'),
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

  Widget _decisionCard(
    String value,
    IconData icon,
    String titleKey,
    String subKey,
  ) {
    final selected = _decision == value;
    return InkWell(
      onTap: () => setState(() => _decision = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? FigmaColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FigmaColors.primary : FigmaColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? FigmaColors.primaryDark : FigmaColors.faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(titleKey),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected
                          ? FigmaColors.primaryDark
                          : FigmaColors.text,
                    ),
                  ),
                  Text(
                    context.tr(subKey),
                    style: const TextStyle(
                      fontSize: 11,
                      color: FigmaColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: FigmaColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
