import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'scanner_game.dart';
import 'scanner_state.dart';
import 'scanner_theme.dart';

/// Reusable Flame-driven Retinal Scanner Component.
///
/// Encapsulates the FlameGame lifecycle, decodes fundus imagery into GPU textures,
/// presents a clinical HUD overlay, and synchronizes with application state.
class ScannerView extends StatefulWidget {
  final Uint8List? imageBytes;
  final ScannerAnimationState state;
  final double progress;
  final bool reduceMotion;
  final String? customStatusText;
  final VoidCallback? onCancel;
  final Widget? overlay;
  final double aspectRatio;
  final bool isInteractive;

  const ScannerView({
    super.key,
    this.imageBytes,
    this.state = ScannerAnimationState.idle,
    this.progress = 0.0,
    this.reduceMotion = false,
    this.customStatusText,
    this.onCancel,
    this.overlay,
    this.aspectRatio = 1.0,
    this.isInteractive = false,
  });

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> with WidgetsBindingObserver {
  late final ScannerGame _game;
  ui.Image? _decodedImage;
  bool _isDecoding = false;
  Uint8List? _lastImageBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = ScannerGame()
      ..animationState = widget.state
      ..progress = widget.progress
      ..reduceMotion = widget.reduceMotion;

    if (widget.imageBytes != null) {
      _decodeImage(widget.imageBytes!);
    }
  }

  @override
  void didUpdateWidget(ScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state != widget.state) {
      _game.animationState = widget.state;
    }
    if (oldWidget.progress != widget.progress) {
      _game.progress = widget.progress;
    }
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      _game.reduceMotion = widget.reduceMotion;
    }

    if (widget.imageBytes != _lastImageBytes && widget.imageBytes != null) {
      _decodeImage(widget.imageBytes!);
    }
  }

  Future<void> _decodeImage(Uint8List bytes) async {
    if (_isDecoding) return;
    _isDecoding = true;
    _lastImageBytes = bytes;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      _decodedImage?.dispose();
      _decodedImage = frame.image;
      _game.fundusImage = _decodedImage;
    } catch (_) {
      // Keep aperture backdrop fallback if decode fails
    } finally {
      _isDecoding = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _game.resumeEngine();
    } else {
      _game.pauseEngine();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.pauseEngine();
    _decodedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.customStatusText ?? widget.state.displayName;
    final stateColor = widget.state.primaryColor;

    return Semantics(
      label: 'Animated retinal scanner in ${widget.state.name} mode',
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: ScannerHUDTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: stateColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: stateColor.withValues(alpha: 0.12),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Flame Canvas Engine & Optional Diagnostic Overlay
              if (widget.isInteractive)
                InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 3.5,
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GameWidget<ScannerGame>(game: _game),
                      if (widget.overlay != null) widget.overlay!,
                    ],
                  ),
                )
              else ...[
                GameWidget<ScannerGame>(game: _game),
                if (widget.overlay != null) widget.overlay!,
              ],

              // 3. Clinical HUD Corner Reticles
              const _HUDCornerMarkers(),

              // 4. Status Bar Header
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: stateColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: stateColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText.toUpperCase(),
                            style: ScannerHUDTheme.hudMonoStyle.copyWith(
                              color: stateColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onCancel != null)
                      GestureDetector(
                        onTap: widget.onCancel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 5. HUD Telemetry Footer
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'FOV: 45° | MACULA CENTERED',
                        overflow: TextOverflow.ellipsis,
                        style: ScannerHUDTheme.hudMonoStyle.copyWith(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    if (widget.progress > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(widget.progress * 100).toInt()}%',
                        style: ScannerHUDTheme.hudMonoStyle.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: stateColor,
                        ),
                      ),
                    ],
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

/// HUD technical corner markers.
class _HUDCornerMarkers extends StatelessWidget {
  const _HUDCornerMarkers();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: const [
            Align(
              alignment: Alignment.topLeft,
              child: _CornerBracket(turns: 0),
            ),
            Align(
              alignment: Alignment.topRight,
              child: _CornerBracket(turns: 1),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _CornerBracket(turns: 2),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _CornerBracket(turns: 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final int turns;

  const _CornerBracket({required this.turns});

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: turns,
      child: CustomPaint(size: const Size(12, 12), painter: _CornerPainter()),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x667DF9FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
