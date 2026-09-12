import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../theme/figma_theme.dart';
import '../widgets/figma_drawer.dart';

/// Figma "Help" screen: 4 FAQ accordions + support card.
/// FAQ bodies are English in the Figma source itself — mirrored as-is.
class FigmaHelpScreen extends StatelessWidget {
  const FigmaHelpScreen({super.key});

  static const _faqs = [
    (
      'help_q1',
      [
        'Position the patient in front of the fundus camera.',
        'Ask the patient to keep their eye wide open and look at the fixation light.',
        'Adjust the camera focus until the retina appears clear.',
        'Capture when the optic disc and macula are both visible.',
        'If quality check fails, retake the image.',
      ],
    ),
    (
      'help_q2',
      [
        'The AI analyses the retinal image and estimates DR severity.',
        'No DR: no signs detected.',
        'Mild NPDR: early signs — microaneurysms.',
        'Moderate NPDR: more changes — specialist review.',
        'Severe NPDR: many changes — referral needed.',
        'PDR: advanced — urgent referral.',
      ],
    ),
    (
      'help_q3',
      [
        'Moderate NPDR or higher severity.',
        'Any vision-threatening changes detected.',
        'No specialist review in 12 months.',
        'Specialist requests re-examination.',
      ],
    ),
    (
      'help_q4',
      [
        'Images are securely saved on the device.',
        'Cases appear in the Offline Queue.',
        'When connectivity returns, press Sync Now.',
        'AI analysis and specialist review proceed automatically.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      drawer: const FigmaDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        title: Text(
          context.tr('help_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.tr('help_subtitle'),
                style: const TextStyle(fontSize: 13, color: FigmaColors.muted),
              ),
              const SizedBox(height: 12),
              ..._faqs.map(
                (faq) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FigmaColors.border),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      context.tr(faq.$1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: FigmaColors.text,
                      ),
                    ),
                    children: [
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: faq.$2
                              .map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• $line',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: FigmaColors.text,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FigmaColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FigmaColors.primaryBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('need_help'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.primaryDark,
                      ),
                    ),
                    Text(
                      context.tr('need_help_msg'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: FigmaColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
