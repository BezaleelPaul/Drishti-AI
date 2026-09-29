import 'dart:typed_data';

import 'package:flutter_litert/flutter_litert.dart';

import 'pipeline_schema.dart';

/// On-device DR classifier (Ticket A-2) wrapping the parity-gated TFLite
/// artifact of final_model.keras via flutter_litert.
///
/// SHIPPED ARTIFACT: fp32 (15.3 MB) — passed the parity gate with 100%
/// top-1 agreement on the clinical corpus; fp16 measurably drifts
/// (83.3% agreement, 0.29 max prob delta — see results/tflite_parity_*.json)
/// and int8 needs a real calibration corpus (converter ready, planned).
/// Upgrade the constant + pubspec line together when a gated artifact lands.
///
/// PARITY CONTRACT (deviation = silent accuracy destruction):
///   - input:  float32, NHWC [1,224,224,3], RAW RGB values in [0,255]
///   - the Rescaling(1/255) -> per-channel Normalization -> Rescaling chain
///     lives INSIDE the model graph — never normalize in Dart
///   - resize: bicubic (PIL parity), performed by the caller on the ORIGINAL
///     image, not by this class
class DrClassifierDart {
  DrClassifierDart({this.assetPath = defaultModelAsset, this.numThreads = 2});

  static const defaultModelAsset =
      'assets/models/dr_efficientnet_b0_fp32.tflite';

  final String assetPath;
  final int numThreads;

  Interpreter? _interpreter;
  bool _initialized = false;

  bool get isReady => _initialized;

  /// Loads the model. Missing/corrupt assets throw [StateError] — callers
  /// must surface AI_UNAVAILABLE and route to human review. Never degrade
  /// to a simulated grade on-device.
  Future<void> initialize() async {
    if (_initialized) return;
    final options = InterpreterOptions()..threads = numThreads;
    try {
      _interpreter = await Interpreter.fromAsset(assetPath, options: options);
    } catch (e) {
      _interpreter = null;
      _initialized = false;
      throw StateError(
        'On-device DR model not loadable ($assetPath): $e. '
        'Run scripts/convert/convert_to_tflite.py and ship the artifact.',
      );
    }
    _initialized = true;
  }

  /// Runs classification on a canonical RGB image already resized to 224x224
  /// (bicubic) and serialized as HxWx3 bytes. Returns the DrClassificationResult
  /// mirroring classifier._build_result, or rethrows on inference failure —
  /// the orchestrator maps failures to AI_UNAVAILABLE (fail closed).
  DrClassificationResult classify(Uint8List rgb224) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('DrClassifierDart not initialized');
    }
    if (rgb224.length != 224 * 224 * 3) {
      throw ArgumentError('Expected 224x224x3 RGB bytes, got ${rgb224.length}');
    }

    // NHWC float32 raw [0,255] — the in-graph Rescaling layer does the rest.
    final input = Float32List(1 * 224 * 224 * 3);
    var j = 0;
    for (var i = 0; i < rgb224.length; i += 3) {
      input[j++] = rgb224[i].toDouble();
      input[j++] = rgb224[i + 1].toDouble();
      input[j++] = rgb224[i + 2].toDouble();
    }

    final output = [List<double>.filled(5, 0.0)];
    interpreter.run(input.buffer, output);

    return _buildResult(List<double>.from(output[0]));
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }

  /// Port of classifier._build_result: sum-normalize, top-1/top-2, margin.
  DrClassificationResult _buildResult(List<double> probs) {
    if (probs.length != 5) {
      throw ArgumentError(
        'Expected 5-class probability vector, got ${probs.length}',
      );
    }
    final total = probs.fold<double>(0.0, (a, b) => a + b);
    if (total <= 0 || total.isNaN || total.isInfinite) {
      throw ArgumentError(
        'Invalid probability vector: sum must be positive and finite',
      );
    }
    final normalized = probs.map((p) => p / total).toList();

    var top1Idx = 0;
    var top2Idx = 1;
    for (var i = 0; i < 5; i++) {
      if (normalized[i] > normalized[top1Idx]) {
        top2Idx = top1Idx;
        top1Idx = i;
      } else if (normalized[i] > normalized[top2Idx]) {
        top2Idx = i;
      }
    }

    final top1Conf = normalized[top1Idx];
    final margin = top1Conf - normalized[top2Idx];
    final grade = DrGrade.fromValue(top1Idx);
    return DrClassificationResult(
      predictedGrade: grade,
      probabilities: normalized,
      confidence: top1Conf,
      top2Margin: margin,
      isReferable: grade.isReferable,
    );
  }
}
