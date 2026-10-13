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

  /// Backend identity recorded in screening rows / reports for traceability.
  /// Must stay in sync with the assets/models/README.md shipped artifact.
  static const backendId = 'tflite-fp32';

  /// Artifact version identity for audit trails.
  static const artifactVersion = 'efficientnet_b0_fp32_v1';

  /// SHA-256 of the shipped fp32 artifact. Used to record model identity in
  /// auditable screening rows; verification against the asset is a build/
  /// release-time check (scripts/convert + validate_tflite_quantized.py).
  static const assetSha256 =
      'CEB819EA01D2FFC3F0C89CC92A66540B04F2711594421ED0B2A391F3620CEB09';

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
  ///
  /// Delegates to the ONE shared derivation
  /// [DrClassificationResult.fromProbabilities] (task 1.2) so the
  /// classifier's result building and the orchestrator conversion (task 2.2)
  /// are computed by the same code and can never disagree. Numbers are
  /// bit-identical to the former inline derivation.
  DrClassificationResult _buildResult(List<double> probs) =>
      DrClassificationResult.fromProbabilities(probs);
}
