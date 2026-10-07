import 'package:flutter_test/flutter_test.dart';
import 'package:netra_ai_mobile/screens/figma_dashboard_screen.dart';
import 'package:netra_ai_mobile/theme/figma_theme.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

void main() {
  group('liveStatusFor', () {
    test('maps backend status tokens to badges', () {
      expect(liveStatusFor('verified'), FigmaStatus.verified);
      expect(liveStatusFor('referral'), FigmaStatus.referral);
      expect(
        liveStatusFor('awaiting_specialist'),
        FigmaStatus.awaitingSpecialist,
      );
      expect(liveStatusFor('rejected'), FigmaStatus.rejected);
      expect(liveStatusFor('awaiting_ai'), FigmaStatus.awaitingAi);
    });

    test('unknown or missing status falls back to verified', () {
      expect(liveStatusFor(null), FigmaStatus.verified);
      expect(liveStatusFor(''), FigmaStatus.verified);
      expect(liveStatusFor('brand_new_state'), FigmaStatus.verified);
    });
  });

  group('formatScreeningDate', () {
    test('formats UTC ISO timestamp as dd MMM yyyy in local time', () {
      const iso = '2026-10-07T13:19:56.173427Z';
      final local = DateTime.parse(iso).toLocal();
      final day = local.day.toString().padLeft(2, '0');
      expect(
        formatScreeningDate(iso),
        '$day ${_months[local.month - 1]} ${local.year}',
      );
    });

    test('pads single-digit days', () {
      const iso = '2026-10-02T00:00:00Z';
      expect(formatScreeningDate(iso).startsWith('0'), isTrue);
    });

    test('handles missing and malformed timestamps', () {
      expect(formatScreeningDate(null), '\u2014');
      expect(formatScreeningDate(''), '\u2014');
      expect(formatScreeningDate('garbage'), 'garbage');
    });
  });
}
