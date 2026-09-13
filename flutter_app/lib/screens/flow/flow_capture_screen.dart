import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/lang_scope.dart';
import '../../services/api_service.dart';
import '../../theme/figma_theme.dart';
import '../../widgets/workflow_bar.dart';
import 'flow_analysis_screen.dart';
import 'flow_state.dart';

/// Figma "Fundus Image Capture" + quality card (Workflow step 2).
/// Eye toggle, bundled samples or device upload, server quality gate.
class FlowCaptureScreen extends StatefulWidget {
  final FlowState state;

  const FlowCaptureScreen({super.key, required this.state});

  @override
  State<FlowCaptureScreen> createState() => _FlowCaptureScreenState();
}

class _FlowCaptureScreenState extends State<FlowCaptureScreen> {
  final _api = ApiService();
  String _sample = 'assets/images/2_clear_eye_normal.jpg';
  bool _checking = false;

  static const _samples = [
    ('assets/images/2_clear_eye_normal.jpg', '2_clear_eye_normal.jpg'),
    ('assets/images/1_blurry_eye_retake.jpg', '1_blurry_eye_retake.jpg'),
    ('assets/images/3_severe_eye_referral.jpg', '3_severe_eye_referral.jpg'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSample(_sample);
  }

  Future<void> _loadSample(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      if (!mounted) return;
      setState(() {
        _sample = asset;
        widget.state.imageBytes = data.buffer.asUint8List();
        widget.state.filename = asset.split('/').last;
        widget.state.quality = null;
      });
      unawaited(_runQuality());
    } catch (_) {}
  }

  Future<void> _upload() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (files != null && files.isNotEmpty && mounted) {
        final picked = files.first;
        final bytes = await picked.readAsBytes();
        setState(() {
          widget.state.imageBytes = bytes;
          widget.state.filename = picked.name;
          widget.state.quality = null;
        });
        unawaited(_runQuality());
      }
    } catch (_) {}
  }

  Future<void> _runQuality() async {
    final bytes = widget.state.imageBytes;
    if (bytes == null) return;
    setState(() => _checking = true);
    try {
      final q = await _api.checkQuality(
        imageBytes: bytes,
        filename: widget.state.filename,
        cameraProfile: widget.state.cameraProfile,
      );
      if (mounted) setState(() => widget.state.quality = q);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _proceed() {
    if (widget.state.imageBytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlowAnalysisScreen(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final q = st.quality;
    final good = q != null && q.qualityGrade == 'GOOD';
    final bad = q != null && q.qualityGrade == 'BAD';
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 1,
        title: Text(
          context.tr('capture_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WorkflowBar(step: 2),
                const SizedBox(height: 12),
                Text(
                  context.tr('select_eye'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'Right',
                      label: Text(context.tr('right_eye')),
                    ),
                    ButtonSegment(
                      value: 'Left',
                      label: Text(context.tr('left_eye')),
                    ),
                  ],
                  selected: {st.eyeSide},
                  onSelectionChanged: (s) =>
                      setState(() => st.eyeSide = s.first),
                ),
                const SizedBox(height: 12),
                // Viewfinder
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: st.imageBytes == null
                      ? Center(
                          child: Text(
                            context.tr('viewfinder_msg'),
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.memory(
                                st.imageBytes!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white54,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.tr('viewfinder_msg')}. ${context.tr('viewfinder_sub')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: FigmaColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _upload,
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(
                          context.tr('btn_upload'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _sample,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: _samples
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.$1,
                                child: Text(
                                  s.$2,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _loadSample(v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Quality card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FigmaColors.border),
                  ),
                  child: _checking
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : q == null
                      ? Text(
                          context.tr('analyzing'),
                          style: const TextStyle(color: FigmaColors.muted),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('quality_title'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: FigmaColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _checkRow(context.tr('retina_visible'), good),
                            _checkRow(context.tr('focus_ok'), good),
                            _checkRow(context.tr('brightness_ok'), good),
                            const SizedBox(height: 6),
                            Text(
                              '${context.tr('quality_label')} ${good ? context.tr('quality_good') : q.qualityGrade}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: good
                                    ? FigmaColors.success
                                    : FigmaColors.warning,
                              ),
                            ),
                            if (bad) ...[
                              const SizedBox(height: 4),
                              Text(
                                context.tr('quality_fail'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: FigmaColors.danger,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: st.imageBytes == null ? null : _proceed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    context.tr('btn_proceed_ai'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? FigmaColors.success : FigmaColors.faint,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: FigmaColors.text),
          ),
        ],
      ),
    );
  }
}
