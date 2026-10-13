import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../scanner/scanner_theme.dart';
import 'orbit_painter.dart';
import 'orbit_state.dart';

/// Reusable orbital retinal scanner.
///
/// Animation-only component: it renders rings, markers and a status label for
/// a caller-provided [OrbitScannerState] and optional caller-verified
/// [technicalLabel]. It never derives progress, model readiness, confidence,
/// predictions or clinical status; screens must map real application events
/// to the state before passing it in.
class OrbitScanner extends StatefulWidget {
  const OrbitScanner({
    super.key,
    required this.state,
    this.imageBytes,
    this.statusText,
    this.technicalLabel,
    this.reduceMotion,
    this.onCancel,
  });

  /// Verified animation state supplied by the caller.
  final OrbitScannerState state;

  /// Selected fundus image for the central slot; renders an eye emblem when null.
  final Uint8List? imageBytes;

  /// Overrides the default state label (e.g. localized or more specific text).
  /// Must describe real state only.
  final String? statusText;

  /// Optional technical readout (e.g. verified backend identity). Rendered
  /// only when provided; never invented by this widget.
  final String? technicalLabel;

  /// Forces reduced-motion rendering. When null, follows
  /// `MediaQuery.disableAnimations`.
  final bool? reduceMotion;

  /// Optional cancel action; the screen owns the actual cancellation flow.
  final VoidCallback? onCancel;

  @override
  State<OrbitScanner> createState() => _OrbitScannerState();
}

class _OrbitScannerState extends State<OrbitScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _reducedMotion = false;

  bool get _shouldAnimate => widget.state.isActiveLoop && !_reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _syncAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion =
        widget.reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant OrbitScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      _reducedMotion =
          widget.reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _statusLabel => widget.statusText ?? widget.state.displayName;

  @override
  Widget build(BuildContext context) {
    final color = widget.state.color;
    final technical = widget.technicalLabel;

    return AspectRatio(
      aspectRatio: 1,
      child: Semantics(
        label:
            'Orbital scanner, $_statusLabel'
            '${technical == null || technical.isEmpty ? '' : ', $technical'}',
        liveRegion: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: OrbitPainter(
                    animationValue: _controller.value,
                    stateColor: color,
                    reducedMotion: _reducedMotion,
                  ),
                ),
              ),
            ),
            Center(
              child: _CentralSlot(imageBytes: widget.imageBytes, color: color),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (technical != null && technical.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ScannerHUDTheme.darkSurface.withValues(
                          alpha: 0.85,
                        ),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        technical.toUpperCase(),
                        style: ScannerHUDTheme.hudMonoStyle.copyWith(
                          color: color,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: ScannerHUDTheme.darkSurface.withValues(
                        alpha: 0.85,
                      ),
                      border: Border.all(color: color.withValues(alpha: 0.7)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: ScannerHUDTheme.hudMonoStyle.copyWith(
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (widget.onCancel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        button: true,
                        label: 'Cancel analysis',
                        child: GestureDetector(
                          key: const Key('orbit_cancel'),
                          onTap: widget.onCancel,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: color.withValues(alpha: 0.6),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CANCEL',
                              style: ScannerHUDTheme.hudMonoStyle.copyWith(
                                color: color,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CentralSlot extends StatelessWidget {
  const _CentralSlot({required this.imageBytes, required this.color});

  final Uint8List? imageBytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final diameter = MediaQuery.sizeOf(context).width * 0.34;

    Widget inner;
    if (imageBytes != null) {
      inner = Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _EyeEmblem(),
      );
    } else {
      inner = const _EyeEmblem();
    }

    return Container(
      width: diameter,
      height: diameter,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 18),
        ],
      ),
      child: inner,
    );
  }
}

class _EyeEmblem extends StatelessWidget {
  const _EyeEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ScannerHUDTheme.background,
      child: CustomPaint(painter: _EyeEmblemPainter()),
    );
  }
}

class _EyeEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = size.width;
    final eye = Paint()
      ..color = const Color(0xFF7DF9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045;

    final path = Path()
      ..moveTo(c.dx - w * 0.36, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - w * 0.30, c.dx + w * 0.36, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + w * 0.30, c.dx - w * 0.36, c.dy)
      ..close();
    canvas.drawPath(path, eye);

    canvas.drawCircle(c, w * 0.14, Paint()..color = const Color(0xFF00B4D8));
    canvas.drawCircle(c, w * 0.06, Paint()..color = const Color(0xFF0B132B));
    canvas.drawCircle(
      c + Offset(-w * 0.04, -w * 0.04),
      w * 0.025,
      Paint()..color = const Color(0xFF7DF9FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
