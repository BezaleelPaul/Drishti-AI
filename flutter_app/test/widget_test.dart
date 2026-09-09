import 'package:flutter_test/flutter_test.dart';
import 'package:netra_ai_mobile/main.dart';

void main() {
  testWidgets('Netra-AI App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const NetraAiApp());
    expect(find.text('Netra-AI Rural Health Screening'), findsOneWidget);
    expect(find.text('Start Eye Scan 📸'), findsOneWidget);
  });
}
