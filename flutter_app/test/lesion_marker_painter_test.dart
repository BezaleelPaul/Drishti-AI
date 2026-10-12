import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netra_ai_mobile/models/retinal_markers.dart';
import 'package:netra_ai_mobile/widgets/review/lesion_marker_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RetinalMarkers buildMarkers({
    bool available = true,
    MarkerCircle? opticDisc,
    MarkerPoint? fovea,
    List<MarkerCircle> maCandidates = const [],
    int width = 1000,
    int height = 1000,
  }) {
    return RetinalMarkers(
      reviewId: 'REV-PAINTER-TEST',
      available: available,
      width: width,
      height: height,
      opticDisc: opticDisc,
      fovea: fovea,
      maCandidates: maCandidates,
    );
  }

  group('LesionMarkerPainter.mapToDisplay', () {
    test('maps source (500, 500) to (200, 200) at 0.4x', () {
      final mapped = LesionMarkerPainter.mapToDisplay(
        const Offset(500, 500),
        Rect.fromLTWH(0, 0, 400, 400),
        0.4,
      );
      expect(mapped.dx, closeTo(200, 1e-9));
      expect(mapped.dy, closeTo(200, 1e-9));
    });

    test('maps inside an offset rect at 1x', () {
      final mapped = LesionMarkerPainter.mapToDisplay(
        const Offset(120, 80),
        Rect.fromLTWH(50, 25, 400, 400),
        1.0,
      );
      expect(mapped.dx, closeTo(170, 1e-9));
      expect(mapped.dy, closeTo(105, 1e-9));
    });

    test('maps source coordinates at 2x', () {
      final mapped = LesionMarkerPainter.mapToDisplay(
        const Offset(75, 120),
        Rect.fromLTWH(0, 0, 800, 800),
        2.0,
      );
      expect(mapped.dx, closeTo(150, 1e-9));
      expect(mapped.dy, closeTo(240, 1e-9));
    });

    test('maps source coordinates at 3.5x (max zoom)', () {
      final mapped = LesionMarkerPainter.mapToDisplay(
        const Offset(200, 100),
        Rect.fromLTWH(10, 20, 1400, 900),
        3.5,
      );
      expect(mapped.dx, closeTo(710, 1e-9));
      expect(mapped.dy, closeTo(370, 1e-9));
    });
  });

  group('LesionMarkerPainter.drawableMarkers', () {
    final imageRect = Rect.fromLTWH(0, 0, 400, 400);

    test('keeps inside markers, keeps edge markers, drops out-of-bounds', () {
      final markers = buildMarkers(
        opticDisc: MarkerCircle(x: 500, y: 500, r: 50),
        fovea: MarkerPoint(x: 900, y: 500),
        maCandidates: [
          MarkerCircle(x: 150, y: 150, r: 8),
          MarkerCircle(x: 1100, y: 500, r: 8),
          MarkerCircle(x: 800, y: 500, r: 8),
          MarkerCircle(x: -5, y: 500, r: 8),
          MarkerCircle(x: 500, y: -5, r: 8),
          MarkerCircle(x: 1050, y: 500, r: 8),
          MarkerCircle(x: 500, y: 1050, r: 8),
        ],
      );

      final drawable = LesionMarkerPainter.drawableMarkers(
        markers,
        imageRect,
        0.4,
      );

      final kinds = drawable.map((m) => m.kind).toList();
      expect(kinds, [
        MarkerKind.opticDisc,
        MarkerKind.fovea,
        MarkerKind.candidate,
        MarkerKind.candidate,
      ]);

      final disc = drawable[0];
      expect(disc.position.dx, closeTo(200, 1e-9));
      expect(disc.position.dy, closeTo(200, 1e-9));
      expect(disc.radius, closeTo(20, 1e-9));

      expect(drawable[1].position.dx, closeTo(360, 1e-9));
      expect(drawable[1].position.dy, closeTo(200, 1e-9));
      expect(drawable[1].radius, greaterThan(0));

      expect(drawable[2].position.dx, closeTo(60, 1e-9));
      expect(drawable[2].position.dy, closeTo(60, 1e-9));
      expect(drawable[3].position.dx, closeTo(320, 1e-9));
      expect(drawable[3].position.dy, closeTo(200, 1e-9));
    });

    test('keeps a marker mapped exactly onto the image edge', () {
      final markers = buildMarkers(
        fovea: MarkerPoint(x: 800, y: 500),
        maCandidates: [MarkerCircle(x: 801, y: 500, r: 8)],
      );

      final drawable = LesionMarkerPainter.drawableMarkers(
        markers,
        imageRect,
        0.5,
      );

      final positions = drawable.map((m) => m.position.dx).toList();
      expect(positions, contains(closeTo(400, 1e-9)));
      expect(
        drawable.any((m) => m.position.dx > 400),
        isFalse,
        reason: 'a mapped centre past the image edge must be skipped',
      );
    });

    test('returns nothing when markers are unavailable', () {
      final markers = buildMarkers(
        available: false,
        opticDisc: MarkerCircle(x: 500, y: 500, r: 50),
        fovea: MarkerPoint(x: 900, y: 500),
        maCandidates: [MarkerCircle(x: 150, y: 150, r: 8)],
      );

      expect(
        LesionMarkerPainter.drawableMarkers(markers, imageRect, 0.4),
        isEmpty,
      );
    });

    test('never invents candidates when the list is empty', () {
      final markers = buildMarkers(
        opticDisc: MarkerCircle(x: 500, y: 500, r: 50),
        fovea: MarkerPoint(x: 900, y: 500),
      );

      final drawable = LesionMarkerPainter.drawableMarkers(
        markers,
        imageRect,
        0.4,
      );

      expect(
        drawable.map((m) => m.kind),
        everyElement(isNot(MarkerKind.candidate)),
      );
      expect(drawable, hasLength(2));
    });

    test(
      'clamps only the display radius of tiny candidates, never the position',
      () {
        final markers = buildMarkers(
          maCandidates: [MarkerCircle(x: 150, y: 150, r: 2)],
        );

        final drawable = LesionMarkerPainter.drawableMarkers(
          markers,
          imageRect,
          0.4,
        );

        expect(drawable, hasLength(1));
        expect(drawable.single.position.dx, closeTo(60, 1e-9));
        expect(drawable.single.position.dy, closeTo(60, 1e-9));
        expect(drawable.single.radius, greaterThanOrEqualTo(2 * 0.4));
      },
    );

    test('does not grow large candidate radii', () {
      final markers = buildMarkers(
        maCandidates: [MarkerCircle(x: 150, y: 150, r: 50)],
      );

      final drawable = LesionMarkerPainter.drawableMarkers(
        markers,
        imageRect,
        0.4,
      );

      expect(drawable.single.radius, closeTo(20, 1e-9));
    });

    test('returns nothing for a degenerate scale', () {
      final markers = buildMarkers(
        opticDisc: MarkerCircle(x: 500, y: 500, r: 50),
        fovea: MarkerPoint(x: 900, y: 500),
        maCandidates: [MarkerCircle(x: 150, y: 150, r: 8)],
      );

      for (final scale in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          LesionMarkerPainter.drawableMarkers(markers, imageRect, scale),
          isEmpty,
          reason: 'scale $scale cannot produce drawable markers',
        );
      }
    });
  });

  group('LesionMarkerPainter.paint', () {
    testWidgets('runs without exceptions with out-of-bounds markers', (
      tester,
    ) async {
      final painter = LesionMarkerPainter(
        markers: buildMarkers(
          opticDisc: MarkerCircle(x: 500, y: 500, r: 50),
          fovea: MarkerPoint(x: 900, y: 500),
          maCandidates: [
            MarkerCircle(x: 150, y: 150, r: 8),
            MarkerCircle(x: 1100, y: 500, r: 8),
          ],
        ),
        imageRect: Rect.fromLTWH(0, 0, 400, 400),
        scale: 0.4,
      );

      await tester.pumpWidget(
        CustomPaint(size: const Size(400, 400), painter: painter),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('runs without exceptions when markers are unavailable', (
      tester,
    ) async {
      final painter = LesionMarkerPainter(
        markers: buildMarkers(available: false),
        imageRect: Rect.fromLTWH(0, 0, 400, 400),
        scale: 0.4,
      );

      await tester.pumpWidget(
        CustomPaint(size: const Size(400, 400), painter: painter),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('LesionMarkerPainter.shouldRepaint', () {
    final imageRect = Rect.fromLTWH(0, 0, 400, 400);
    final markers = buildMarkers(
      opticDisc: MarkerCircle(x: 500, y: 500, r: 50),
    );

    LesionMarkerPainter painter({
      RetinalMarkers? markersOverride,
      Rect? imageRectOverride,
      double? scaleOverride,
      double? strokeScaleOverride,
    }) {
      return LesionMarkerPainter(
        markers: markersOverride ?? markers,
        imageRect: imageRectOverride ?? imageRect,
        scale: scaleOverride ?? 0.4,
        strokeScale: strokeScaleOverride ?? 1.0,
      );
    }

    test('returns false when all fields are identical', () {
      final base = painter();
      final same = painter();

      expect(base.shouldRepaint(same), isFalse);
    });

    test('returns true when markers change identity', () {
      final base = painter();
      final changed = painter(markersOverride: buildMarkers());

      expect(base.shouldRepaint(changed), isTrue);
    });

    test('returns true when imageRect changes', () {
      final base = painter();
      final changed = painter(
        imageRectOverride: Rect.fromLTWH(10, 0, 400, 400),
      );

      expect(base.shouldRepaint(changed), isTrue);
    });

    test('returns true when scale changes', () {
      final base = painter();
      final changed = painter(scaleOverride: 0.5);

      expect(base.shouldRepaint(changed), isTrue);
    });

    test('returns true when strokeScale changes', () {
      final base = painter();
      final changed = painter(strokeScaleOverride: 2.0);

      expect(base.shouldRepaint(changed), isTrue);
    });
  });
}
