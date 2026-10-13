import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/retinal_markers.dart';
import '../scanner/scanner_theme.dart';

/// Paints retinal markers over the displayed fundus image.
///
/// Visual grammar: optic disc -> circle outline, fovea -> crosshair, each
/// microaneurysm candidate -> small ring with a soft "found here" pulse and
/// (when callouts are on) a leader arrow + honest text label. Markers come
/// only from the supplied [RetinalMarkers] (source pixel space) and are
/// mapped into [imageRect], the actual displayed-image rect; any marker
/// whose mapped centre falls outside that rect is skipped, so nothing is
/// ever drawn beyond the image bounds.
///
/// Callout copy states what the marker IS — a lesion candidate located by
/// classical CV segmentation — never a diagnosis (provenance rule).
class LesionMarkerPainter extends CustomPainter {
  const LesionMarkerPainter({
    required this.markers,
    required this.imageRect,
    required this.scale,
    this.strokeScale = 1.0,
    this.pulse = 0.0,
    this.showCallouts = false,
  });

  static const double _baseStrokeWidth = 2.0;
  static const double _candidateStrokeWidth = 1.6;
  static const double _minCandidateDisplayRadius = 3.0;
  static const double _foveaArmLength = 8.0;

  /// Pulse animation phase (0..1): drives the expanding "found area" ring
  /// so a static screenshot is identical to the legacy rendering.
  final double pulse;

  /// Whether callout arrows + labels are drawn (on by the live viewer).
  final bool showCallouts;

  /// At most this many lesion callouts are labelled; dense candidate sets
  /// would otherwise soup the image with arrows.
  static const int _maxCallouts = 4;

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
          // "AI found something here" affordance: soft halo fill + crisp
          // ring, then an expanding pulse ring locked to [pulse].
          final halo = Paint()..color = _soften(ScannerHUDTheme.warning, 0.12);
          canvas.drawCircle(marker.position, marker.radius + 2.0, halo);
          canvas.drawCircle(
            marker.position,
            marker.radius,
            _strokePaint(ScannerHUDTheme.warning, _candidateStrokeWidth),
          );
          if (pulse > 0.0 && pulse < 1.0) {
            final alpha = (1.0 - pulse) * 0.55;
            canvas.drawCircle(
              marker.position,
              marker.radius + 4.0 + 12.0 * pulse,
              _strokePaint(ScannerHUDTheme.warning, 1.4)
                ..color = _soften(ScannerHUDTheme.warning, alpha),
            );
          }
      }
    }

    if (showCallouts) _paintCallouts(canvas);
    canvas.restore();
  }

  /// Leader arrows + honest text labels for the first [_maxCallouts]
  /// rendered candidates, plus one-line anatomical captions. Anchored so
  /// the pill stays inside the image rect (never drawn over the letterbox).
  void _paintCallouts(Canvas canvas) {
    final candidates = drawableMarkers(
      markers,
      imageRect,
      scale,
    ).where((m) => m.kind == MarkerKind.candidate).toList();
    var index = 0;
    for (final marker in candidates.take(_maxCallouts)) {
      final onLeft = marker.position.dx < imageRect.center.dx;
      final ok = _drawCallout(
        canvas: canvas,
        target: marker.position,
        radius: marker.radius,
        text: 'Suspected microaneurysm #${++index} (classical CV)',
        onLeft: onLeft,
      );
      if (!ok) break;
    }
    for (final marker in drawableMarkers(markers, imageRect, scale)) {
      if (marker.kind == MarkerKind.opticDisc) {
        _drawLabel(
          canvas,
          marker.position.translate(8, marker.radius + 10),
          'Optic disc',
        );
      } else if (marker.kind == MarkerKind.fovea) {
        _drawLabel(canvas, marker.position.translate(8, 14), 'Fovea');
      }
    }
  }

  /// Arrow + label for one candidate: label pill offset away from the
  /// target, leader line ending in an arrowhead at the ring edge. Returns
  /// false when the label cannot be placed inside [imageRect].
  bool _drawCallout({
    required Canvas canvas,
    required Offset target,
    required double radius,
    required String text,
    required bool onLeft,
  }) {
    const labelGap = 26.0;
    final direction = onLeft
        ? const Offset(-1.0, -0.6)
        : const Offset(1.0, -0.6);
    final anchor = target + direction * labelGap;
    final textSize = _measure(text);
    final pillSize = textSize + const Offset(12, 8);
    var pillTopLeft =
        anchor -
        Offset(direction.dx < 0 ? pillSize.width : 0, 0) +
        Offset(0, -pillSize.height / 2);
    // Clamp inside the image rect; if the pill cannot fit, skip callout.
    pillTopLeft = Offset(
      pillTopLeft.dx.clamp(
        imageRect.left + 2,
        imageRect.right - pillSize.width - 2,
      ),
      pillTopLeft.dy.clamp(
        imageRect.top + 2,
        imageRect.bottom - pillSize.height - 2,
      ),
    );
    if (pillTopLeft.dx.isNaN || pillSize.width > imageRect.width - 4) {
      return false;
    }
    final pillRect = Rect.fromLTWH(
      pillTopLeft.dx,
      pillTopLeft.dy,
      pillSize.width,
      pillSize.height,
    );

    // Leader from the pill edge nearest the target toward the ring,
    // stopping at radius + 4 so the arrowhead does not cover the ring.
    final pillAttach = Offset(
      pillRect.left < target.dx ? pillRect.right : pillRect.left,
      pillRect.center.dy,
    );
    final span = target - pillAttach;
    final spanLength = span.distance;
    if (spanLength < radius + 6) return false;
    final stop = pillAttach + span * ((spanLength - radius - 4) / spanLength);
    final leader = _strokePaint(_soften(ScannerHUDTheme.warning, 0.9), 1.3)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pillAttach, stop, leader);

    // Arrowhead at [stop], oriented along the leader.
    final angle = math.atan2(span.dy, span.dx);
    const headLength = 7.0;
    final head = Path()
      ..moveTo(stop.dx, stop.dy)
      ..lineTo(
        stop.dx - headLength * math.cos(angle - 0.45),
        stop.dy - headLength * math.sin(angle - 0.45),
      )
      ..lineTo(
        stop.dx - headLength * math.cos(angle + 0.45),
        stop.dy - headLength * math.sin(angle + 0.45),
      )
      ..close();
    canvas.drawPath(
      head,
      Paint()..color = _soften(ScannerHUDTheme.warning, 0.95),
    );

    _drawLabelAt(canvas, pillRect, text);
    return true;
  }

  void _drawLabel(Canvas canvas, Offset anchor, String text) {
    final size = _measure(text);
    final pill = Rect.fromLTWH(
      anchor.dx.clamp(
        imageRect.left + 2,
        (imageRect.right - size.width - 12).clamp(2.0, double.infinity),
      ),
      anchor.dy.clamp(
        imageRect.top + 2,
        (imageRect.bottom - size.height - 10).clamp(2.0, double.infinity),
      ),
      size.width + 12,
      size.height + 8,
    );
    _drawLabelAt(canvas, pill, text);
  }

  void _drawLabelAt(Canvas canvas, Rect pill, String text) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(pill, const Radius.circular(4)),
      Paint()..color = _soften(const Color(0xFF0F172A), 0.82),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pill, const Radius.circular(4)),
      _strokePaint(_soften(ScannerHUDTheme.warning, 0.55), 1.0),
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: imageRect.width - 16);
    painter.paint(
      canvas,
      Offset(pill.left + 6, pill.center.dy - painter.height / 2),
    );
  }

  Size _measure(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: imageRect.width - 16);
    return Size(painter.width, painter.height);
  }

  static const _labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: Color(0xFFFDE68C),
  );

  static Color _soften(Color base, double alpha) =>
      base.withValues(alpha: alpha.clamp(0.0, 1.0));

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
      oldDelegate.strokeScale != strokeScale ||
      oldDelegate.pulse != pulse ||
      oldDelegate.showCallouts != showCallouts;
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
