import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../theme/figma_theme.dart';

/// Live fundus capture (Ticket: camera integration).
///
/// Full-screen back-camera preview with tap-to-capture and lens switch.
/// Returns the captured JPEG bytes to the caller via Navigator.pop. The
/// quality gate runs back on the capture screen (same on-device pipeline),
/// so this screen does one thing only: put a well-framed frame in the circle.
class LiveFundusCameraScreen extends StatefulWidget {
  const LiveFundusCameraScreen({super.key});

  @override
  State<LiveFundusCameraScreen> createState() => _LiveFundusCameraScreenState();
}

class _LiveFundusCameraScreenState extends State<LiveFundusCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _lens = 0;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _error = 'No camera available on this device.';
        });
        return;
      }
      _cameras = cameras;
      // Prefer the back camera for fundus capture.
      _lens = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_lens < 0) _lens = 0;
      await _open(_cameras[_lens]);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Camera error: ${e.code} ${e.description ?? ''}'.trim();
      });
    }
  }

  Future<void> _open(CameraDescription description) async {
    final previous = _controller;
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    previous?.dispose();
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _switchLens() async {
    if (_cameras.length < 2) return;
    setState(() => _initializing = true);
    _lens = (_lens + 1) % _cameras.length;
    await _open(_cameras[_lens]);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture failed: ${e.code}'),
          backgroundColor: FigmaColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          context.tr('capture_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Switch camera',
              onPressed: _initializing ? null : _switchLens,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: Center(child: _buildBody(ready, controller)),
    );
  }

  Widget _buildBody(bool ready, CameraController? controller) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: FigmaColors.danger,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_initializing || !ready || controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Starting camera…',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        // Framing guide: a centered retinal-field circle, purely visual.
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: _captureButton(),
          ),
        ),
      ],
    );
  }

  Widget _captureButton() {
    return GestureDetector(
      onTap: _capturing ? null : _capture,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _capturing ? Colors.white38 : Colors.white,
            ),
            child: _capturing
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
