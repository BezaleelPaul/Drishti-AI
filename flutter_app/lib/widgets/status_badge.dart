import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../theme/figma_theme.dart';

/// Figma `StatusBadge`: rounded pill, localized label, Figma colors.
class StatusBadge extends StatelessWidget {
  final FigmaStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.border),
      ),
      child: Text(
        context.tr(status.labelKey),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.fg,
        ),
      ),
    );
  }
}
