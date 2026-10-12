import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/retinal_markers.dart';
import 'lesion_marker_painter.dart';

/// Clinician-side zoom + wipe viewer for one review case.
///
/// Markers and image load independently through injected fetchers (the
/// review screen wires these to ApiService); a marker failure degrades to
/// an honest unavailable state over the real image — never a decorative
/// overlay (Req 5.3).
typedef MarkerFetcher = Future<RetinalMarkers> Function(String reviewId);
typedef ReviewImageFetcher = Future<Uint8List> Function(String reviewId);

class ClinicianMarkerViewer extends StatefulWidget {
  const ClinicianMarkerViewer({
    super.key,
    required this.reviewId,
    this.fetchMarkers,
    this.fetchImage,
  });

  final String reviewId;
  final MarkerFetcher? fetchMarkers;
  final ReviewImageFetcher? fetchImage;

  /// Req 3.3: pinch-zoom must reach at least 3.5x the fitted size.
  static const double maxZoom = 3.5;

  /// The BoxFit.contain letterbox rect for a [srcW]x[srcH] source inside
  /// [viewport]. This is the real displayed-image rect in the zoom child's
  /// coordinate space and is handed to the painter as imageRect, so markers
  /// land on their anatomy (task 3.1's obligation to the viewer).
  static Rect fittedImageRect(Size viewport, double srcW, double srcH) {
    if (srcW <= 0 || srcH <= 0 || viewport.isEmpty) return Rect.zero;
    final scale = math.min(viewport.width / srcW, viewport.height / srcH);
    final width = srcW * scale;
    final height = srcH * scale;
    return Rect.fromLTWH(
      (viewport.width - width) / 2,
      (viewport.height - height) / 2,
      width,
      height,
    );
  }

  @override
  State<ClinicianMarkerViewer> createState() => _ClinicianMarkerViewerState();
}

enum _MarkerLoad { loading, available, unavailable }

enum _ImageLoad { loading, loaded, failed }

class _ClinicianMarkerViewerState extends State<ClinicianMarkerViewer> {
  _MarkerLoad _markerLoad = _MarkerLoad.loading;
  RetinalMarkers? _markers;
  String? _markerDetail;
  _ImageLoad _imageLoad = _ImageLoad.loading;
  Uint8List? _imageBytes;
  String? _imageDetail;

  /// Wipe default: fully marked view — the doctor sees markers without
  /// interaction; dragging left reveals the plain view (Req 4.1).
  double _wipeFraction = 1.0;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _loadImage();
  }

  Future<void> _loadMarkers() async {
    final fetcher = widget.fetchMarkers;
    if (fetcher == null) {
      _setMarkersUnavailable('No marker source configured.');
      return;
    }
    try {
      final markers = await fetcher(widget.reviewId);
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _markerLoad = markers.available
            ? _MarkerLoad.available
            : _MarkerLoad.unavailable;
        _markerDetail = markers.available
            ? null
            : (markers.reason ??
                  'Markers could not be computed for this case.');
      });
    } catch (error) {
      _setMarkersUnavailable('Marker load failed: $error');
    }
  }

  void _setMarkersUnavailable(String detail) {
    if (!mounted) return;
    setState(() {
      _markerLoad = _MarkerLoad.unavailable;
      _markerDetail = detail;
    });
  }

  Future<void> _loadImage() async {
    final fetcher = widget.fetchImage;
    if (fetcher == null) {
      _setImageFailed('No image source configured.');
      return;
    }
    try {
      final bytes = await fetcher(widget.reviewId);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageLoad = _ImageLoad.loaded;
      });
    } catch (error) {
      _setImageFailed('$error');
    }
  }

  void _setImageFailed(String detail) {
    if (!mounted) return;
    setState(() {
      _imageLoad = _ImageLoad.failed;
      _imageDetail = detail;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_imageLoad == _ImageLoad.failed) {
      return _ImageErrorState(detail: _imageDetail);
    }
    return Column(
      children: [
        Expanded(child: _zoomableLayers()),
        if (_imageLoad == _ImageLoad.loaded) _statusFooter(),
      ],
    );
  }

  /// ONE InteractiveViewer carries BOTH layers, so zoom/pan stay identical
  /// by construction under the wipe (Req 4.2). The painter sits inside the
  /// transform, so strokeScale stays 1.0 (task 3.1 review note).
  Widget _zoomableLayers() {
    return InteractiveViewer(
      panEnabled: true,
      minScale: 1.0,
      maxScale: ClinicianMarkerViewer.maxZoom,
      child: _imageLoad == _ImageLoad.loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.biggest;
                final markers = _markers;
                final markedReady =
                    _markerLoad == _MarkerLoad.available &&
                    markers != null &&
                    markers.width > 0 &&
                    markers.height > 0;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                    ),
                    if (markedReady) _markedLayer(viewport, markers),
                  ],
                );
              },
            ),
    );
  }

  /// Marked layer: same image bytes + marker painter, clipped to
  /// [_wipeFraction] of the viewport width (Req 4.1).
  Widget _markedLayer(Size viewport, RetinalMarkers markers) {
    final imageRect = ClinicianMarkerViewer.fittedImageRect(
      viewport,
      markers.width.toDouble(),
      markers.height.toDouble(),
    );
    return ClipRect(
      clipper: WipeFractionClipper(_wipeFraction),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_imageBytes!, fit: BoxFit.contain),
          Positioned.fill(
            child: CustomPaint(
              painter: LesionMarkerPainter(
                markers: markers,
                imageRect: imageRect,
                scale: imageRect.width / markers.width,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusFooter() {
    switch (_markerLoad) {
      case _MarkerLoad.loading:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Loading markers…'),
        );
      case _MarkerLoad.unavailable:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Markers unavailable'),
              if (_markerDetail != null)
                Text(
                  _markerDetail!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        );
      case _MarkerLoad.available:
        final markers = _markers!;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: _wipeFraction,
                onChanged: (value) => setState(() => _wipeFraction = value),
              ),
              Text(
                markers.maCandidates.isEmpty
                    ? 'No lesion candidates found — anatomical landmarks only.'
                    : 'Markers: ${RetinalMarkers.classicalCvSource} · drag the '
                          'slider to wipe between the plain and marked view.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
    }
  }
}

/// Clips the marked layer to the left [fraction] of the width: the
/// drag-to-reveal wipe (Req 4.1). Public so tests can read the live wipe
/// fraction through `getClip`.
class WipeFractionClipper extends CustomClipper<Rect> {
  const WipeFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      0,
      0,
      size.width * fraction.clamp(0.0, 1.0),
      size.height,
    );
  }

  @override
  bool shouldReclip(WipeFractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _ImageErrorState extends StatelessWidget {
  const _ImageErrorState({this.detail});

  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fundus image could not be loaded.'),
            if (detail != null)
              Text(
                detail!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
