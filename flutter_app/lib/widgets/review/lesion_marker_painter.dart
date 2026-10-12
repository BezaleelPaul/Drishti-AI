import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/retinal_markers.dart';
import '../scanner/scanner_theme.dart';

/// Paints retinal markers over the displayed fundus image.
///
/// Visual grammar: optic disc -> circle outline, fovea -> crosshair, each
/// microaneurysm candidate -> small ring. Markers come only from the supplied
/// [RetinalMarkers] (source pixel space) and are mapped into [imageRect], the
/// actual displayed-image rect; any marker whose mapped centre falls outside
/// that rect is skipped, so nothing is ever drawn beyond the image bounds.
class LesionMarkerPainter extends CustomPainter {
  const LesionMarkerPainter({
    required this.markers,
    required this.imageRect,
    required this.scale,
    this.strokeScale = 1.0,
  });

  static const double _baseStrokeWidth = 2.0;
  static const double _candidateStrokeWidth = 1.6;
  static const double _minCandidateDisplayRadius = 3.0;
  static const double _foveaArmLength = 8.0;

  final RetinalMarkers markers;

  /// Destination rect of the displayed image, in the painter's coordinate
  /// space; the viewer is responsible for handing the real fitted rect.
  final Rect imageRect;

  /// Displayed size / source size; scales marker geometry.
  final double scale;

  final double strokeScale;

  static Offset mapToDisplay(Offset source, Rect imageRect, double scale) {
    return Offset(
      imageRect.left + source.dx * scale,
      imageRect.top + source.dy * scale,
    );
  }

  static List<MarkerToDraw> drawableMarkers(
    RetinalMarkers markers,
    Rect imageRect,
    double scale,
  ) {
    if (!markers.available) return const [];
    if (scale.isNaN || scale.isInfinite || scale <= 0) return const [];

    final out = <MarkerToDraw>[];

    final disc = markers.opticDisc;
    if (disc != null) {
      final position = mapToDisplay(
        Offset(disc.x.toDouble(), disc.y.toDouble()),
        imageRect,
        scale,
      );
      if (_isRenderable(position, imageRect)) {
        out.add(
          MarkerToDraw(
            kind: MarkerKind.opticDisc,
            position: position,
            radius: disc.r * scale,
          ),
        );
      }
    }

    final fovea = markers.fovea;
    if (fovea != null) {
      final position = mapToDisplay(
        Offset(fovea.x.toDouble(), fovea.y.toDouble()),
        imageRect,
        scale,
      );
      if (_isRenderable(position, imageRect)) {
        out.add(
          MarkerToDraw(
            kind: MarkerKind.fovea,
            position: position,
            radius: _foveaArmLength,
          ),
        );
      }
    }

    for (final candidate in markers.maCandidates) {
      final position = mapToDisplay(
        Offset(candidate.x.toDouble(), candidate.y.toDouble()),
        imageRect,
        scale,
      );
      if (_isRenderable(position, imageRect)) {
        out.add(
          MarkerToDraw(
            kind: MarkerKind.candidate,
            position: position,
            radius: math.max(candidate.r * scale, _minCandidateDisplayRadius),
          ),
        );
      }
    }

    return out;
  }

  static bool _isRenderable(Offset position, Rect imageRect) {
    if (!position.dx.isFinite || !position.dy.isFinite) return false;
    return position.dx >= imageRect.left &&
        position.dx <= imageRect.right &&
        position.dy >= imageRect.top &&
        position.dy <= imageRect.bottom;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(imageRect);
    for (final marker in drawableMarkers(markers, imageRect, scale)) {
      switch (marker.kind) {
        case MarkerKind.opticDisc:
          canvas.drawCircle(
            marker.position,
            marker.radius,
            _strokePaint(ScannerHUDTheme.neonCyan, _baseStrokeWidth),
          );
        case MarkerKind.fovea:
          final arm = marker.radius;
          final paint = _strokePaint(Colors.white, _baseStrokeWidth)
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(marker.position.dx - arm, marker.position.dy),
            Offset(marker.position.dx + arm, marker.position.dy),
            paint,
          );
          canvas.drawLine(
            Offset(marker.position.dx, marker.position.dy - arm),
            Offset(marker.position.dx, marker.position.dy + arm),
            paint,
          );
        case MarkerKind.candidate:
          canvas.drawCircle(
            marker.position,
            marker.radius,
            _strokePaint(ScannerHUDTheme.warning, _candidateStrokeWidth),
          );
      }
    }
    canvas.restore();
  }

  Paint _strokePaint(Color color, double width) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * strokeScale;
  }

  @override
  bool shouldRepaint(covariant LesionMarkerPainter oldDelegate) =>
      oldDelegate.markers != markers ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.scale != scale ||
      oldDelegate.strokeScale != strokeScale;
}

enum MarkerKind { opticDisc, fovea, candidate }

class MarkerToDraw {
  const MarkerToDraw({
    required this.kind,
    required this.position,
    required this.radius,
  });

  final MarkerKind kind;
  final Offset position;
  final double radius;
}
