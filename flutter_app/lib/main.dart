import 'package:flutter/material.dart';
import 'l10n/lang_scope.dart';
import 'screens/figma_dashboard_screen.dart';
import 'theme/figma_theme.dart';

void main() {
  runApp(NetraAiApp(langController: LangController()));
}

class NetraAiApp extends StatelessWidget {
  final LangController langController;

  const NetraAiApp({super.key, required this.langController});

  @override
  Widget build(BuildContext context) {
    return LangScope(
      notifier: langController,
      child: MaterialApp(
        title: 'Netra-AI Rural Health Screening',
        debugShowCheckedModeBanner: false,
        theme: buildFigmaTheme(),
        home: const FigmaDashboardScreen(),
      ),
    );
  }
}
