import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:netra_ai_mobile/l10n/lang_scope.dart';
import 'package:netra_ai_mobile/main.dart';

void main() {
  testWidgets('Netra-AI App Smoke Test', (WidgetTester tester) async {
    // No network in widget tests: fall back to bundled fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(NetraAiApp(langController: LangController()));
    // Figma dashboard home (English default).
    expect(find.text('PHC Dashboard'), findsOneWidget);
    expect(find.text('+ Start New Screening'), findsOneWidget);
    expect(find.text('Recent Screenings'), findsOneWidget);
  });
}
