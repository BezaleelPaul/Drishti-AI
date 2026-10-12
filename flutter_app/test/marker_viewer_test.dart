import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netra_ai_mobile/models/retinal_markers.dart';
import 'package:netra_ai_mobile/widgets/review/lesion_marker_painter.dart';
import 'package:netra_ai_mobile/widgets/review/marker_viewer.dart';

/// Real 1x1 red PNG so Image.memory decodes cleanly in the test binding.
const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Uint8List _pngBytes() => base64Decode(_tinyPngBase64);

RetinalMarkers _markers({
  bool available = true,
  String? reason,
  List<MarkerCircle>? candidates,
}) {
  return RetinalMarkers(
    reviewId: 'REV-TEST',
    available: available,
    reason: reason,
    width: available ? 1000 : 0,
    height: available ? 1000 : 0,
    opticDisc: available ? MarkerCircle(x: 300, y: 320, r: 80) : null,
    fovea: available ? MarkerPoint(x: 640, y: 540) : null,
    maCandidates:
        candidates ?? (available ? [MarkerCircle(x: 420, y: 310, r: 14)] : []),
  );
}

Future<void> _pumpViewer(
  WidgetTester tester, {
  MarkerFetcher? fetchMarkers,
  ReviewImageFetcher? fetchImage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: ClinicianMarkerViewer(
              reviewId: 'REV-TEST',
              fetchMarkers: fetchMarkers,
              fetchImage: fetchImage,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

final Finder _markerPaintFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is LesionMarkerPainter,
);

final Finder _wipeClipFinder = find.byWidgetPredicate(
  (w) => w is ClipRect && w.clipper is WipeFractionClipper,
);

Rect _wipeClip(WidgetTester tester) {
  final clip = tester.widget<ClipRect>(_wipeClipFinder);
  return (clip.clipper as WipeFractionClipper).getClip(const Size(400, 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fittedImageRect computes the BoxFit.contain letterbox rect', () {
    expect(
      ClinicianMarkerViewer.fittedImageRect(const Size(400, 400), 1000, 500),
      Rect.fromLTWH(0, 100, 400, 200),
    );
    expect(
      ClinicianMarkerViewer.fittedImageRect(const Size(400, 400), 500, 1000),
      Rect.fromLTWH(100, 0, 200, 400),
    );
    expect(
      ClinicianMarkerViewer.fittedImageRect(const Size(400, 300), 1000, 1000),
      Rect.fromLTWH(50, 0, 300, 300),
    );
  });

  testWidgets(
    'available markers: both layers render, painter inside the one transform, slider present, default fully revealed',
    (tester) async {
      await _pumpViewer(
        tester,
        fetchMarkers: (_) async => _markers(),
        fetchImage: (_) async => _pngBytes(),
      );

      final viewer = find.byType(InteractiveViewer);
      expect(viewer, findsOneWidget);
      expect(
        find.descendant(of: viewer, matching: find.byType(Image)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: viewer, matching: _markerPaintFinder),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsOneWidget);

      final paint = tester.widget<CustomPaint>(_markerPaintFinder);
      final painter = paint.painter! as LesionMarkerPainter;
      expect(painter.strokeScale, 1.0);
      expect(painter.scale, closeTo(painter.imageRect.width / 1000, 1e-9));

      // Square 1000x1000 source contain-fits: square rect, centered on the
      // 400-wide viewport, within the Expanded height left by the footer.
      final imageRect = painter.imageRect;
      expect(imageRect.width, closeTo(imageRect.height, 1e-6));
      expect(imageRect.left, closeTo((400 - imageRect.width) / 2, 1e-6));
      expect(imageRect.width, greaterThan(0));
      expect(imageRect.height, lessThanOrEqualTo(400));

      expect(_wipeClip(tester), Rect.fromLTWH(0, 0, 400, 400));
    },
  );

  testWidgets('dragging the wipe slider shrinks the marked-layer clip', (
    tester,
  ) async {
    await _pumpViewer(
      tester,
      fetchMarkers: (_) async => _markers(),
      fetchImage: (_) async => _pngBytes(),
    );

    await tester.drag(find.byType(Slider), const Offset(-160, 0));
    await tester.pump();
    await tester.pump();

    final clip = _wipeClip(tester);
    expect(clip.left, 0.0);
    expect(clip.right, lessThan(400.0));
    expect(clip.right, greaterThanOrEqualTo(0.0));
  });

  testWidgets('zoom supports at least 3.5x with pan enabled', (tester) async {
    await _pumpViewer(
      tester,
      fetchMarkers: (_) async => _markers(),
      fetchImage: (_) async => _pngBytes(),
    );

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(iv.maxScale, greaterThanOrEqualTo(3.5));
    expect(iv.minScale, 1.0);
    expect(iv.panEnabled, true);
  });

  testWidgets('unavailable markers: honest text, no slider, no painter', (
    tester,
  ) async {
    await _pumpViewer(
      tester,
      fetchMarkers: (_) async =>
          _markers(available: false, reason: 'segmentation failed'),
      fetchImage: (_) async => _pngBytes(),
    );

    expect(find.textContaining('unavailable'), findsWidgets);
    expect(find.textContaining('segmentation failed'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(_markerPaintFinder, findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('marker fetch failure degrades to honest unavailable state', (
    tester,
  ) async {
    await _pumpViewer(
      tester,
      fetchMarkers: (_) async => throw Exception('network down'),
      fetchImage: (_) async => _pngBytes(),
    );

    expect(find.textContaining('unavailable'), findsWidgets);
    expect(find.byType(Image), findsOneWidget);
    expect(_markerPaintFinder, findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('available with empty candidates: painter + honest note', (
    tester,
  ) async {
    await _pumpViewer(
      tester,
      fetchMarkers: (_) async => _markers(candidates: const []),
      fetchImage: (_) async => _pngBytes(),
    );

    expect(_markerPaintFinder, findsOneWidget);
    expect(find.textContaining('No lesion candidates'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('image failure: honest error, no image, no markers, no slider', (
    tester,
  ) async {
    await _pumpViewer(
      tester,
      fetchMarkers: (_) async => _markers(),
      fetchImage: (_) async => throw Exception('boom'),
    );

    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(_markerPaintFinder, findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('loading: markers never render before real image pixels', (
    tester,
  ) async {
    final imageReady = Completer<Uint8List>();
    final markersReady = Completer<RetinalMarkers>();
    await _pumpViewer(
      tester,
      fetchMarkers: (_) => markersReady.future,
      fetchImage: (_) => imageReady.future,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(_markerPaintFinder, findsNothing);
    expect(find.byType(Slider), findsNothing);

    markersReady.complete(_markers());
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(_markerPaintFinder, findsNothing);
    expect(find.byType(Slider), findsNothing);

    imageReady.complete(_pngBytes());
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsNWidgets(2));
    expect(_markerPaintFinder, findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('markers pending after image loaded: honest loading note', (
    tester,
  ) async {
    final imageReady = Completer<Uint8List>();
    final markersReady = Completer<RetinalMarkers>();
    await _pumpViewer(
      tester,
      fetchMarkers: (_) => markersReady.future,
      fetchImage: (_) => imageReady.future,
    );

    imageReady.complete(_pngBytes());
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Loading markers'), findsOneWidget);
    expect(_markerPaintFinder, findsNothing);
    expect(find.byType(Slider), findsNothing);

    markersReady.complete(_markers());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Loading markers'), findsNothing);
    expect(_markerPaintFinder, findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
