import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../theme/figma_theme.dart';
import '../widgets/status_badge.dart';

/// Minimal Figma "Patient History" screen backing dashboard row taps.
/// Read-only demo list reusing Figma history data + status pills.
class FigmaHistoryScreen extends StatelessWidget {
  const FigmaHistoryScreen({super.key});

  static const _entries = [
    (
      'September 2026',
      'Moderate NPDR',
      FigmaStatus.verified,
      FigmaColors.warning,
    ),
    ('June 2026', 'Mild NPDR', FigmaStatus.verified, FigmaColors.success),
    ('March 2026', 'No DR', FigmaStatus.verified, FigmaColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        title: Text(
          context.tr('history_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.tr('screening_history'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: FigmaColors.text,
                ),
              ),
              const SizedBox(height: 10),
              ..._entries.map(
                (e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FigmaColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e.$4,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: FigmaColors.text,
                              ),
                            ),
                            Text(
                              e.$1,
                              style: const TextStyle(
                                fontSize: 12,
                                color: FigmaColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: e.$3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('demo_data'),
                style: const TextStyle(fontSize: 11, color: FigmaColors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
