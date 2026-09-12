import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../theme/figma_theme.dart';

/// Figma `WorkflowBar`: 5 connected step dots
/// (Patient → Image → AI → Specialist → Report).
class WorkflowBar extends StatelessWidget {
  /// 1-based active step.
  final int step;

  const WorkflowBar({super.key, required this.step});

  static const _keys = [
    'wf_patient',
    'wf_image',
    'wf_ai',
    'wf_specialist',
    'wf_report',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _keys.length; i++) ...[
          _dot(context, i + 1, context.tr(_keys[i])),
          if (i < _keys.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 22, left: 4, right: 4),
                color: (i + 1) < step
                    ? FigmaColors.success
                    : FigmaColors.border,
              ),
            ),
        ],
      ],
    );
  }

  Widget _dot(BuildContext context, int index, String label) {
    final done = index < step;
    final active = index == step;
    final bg = done
        ? FigmaColors.success
        : active
        ? FigmaColors.primary
        : const Color(0xFFF1F5F9);
    final fg = (done || active) ? Colors.white : FigmaColors.faint;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: active
                ? FigmaColors.primaryDark
                : done
                ? FigmaColors.success
                : FigmaColors.faint,
          ),
        ),
      ],
    );
  }
}
