import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

import 'model_runner.dart';
import 'pipeline_schema.dart';

/// On-device runner for the DRDetect ordinal-regression model, converted
/// from `efficientnet_b0_regression_512px.onnx` via onnx2tf and parity-gated
/// against the ONNX reference (10/10 grade agreement, max |score diff|
/// 3e-5 — see results/drdetect_tflite_parity.json).
///
/// ARTIFACT CONTRACT (deviation = silent accuracy destruction):
///   - asset:  assets/models/drdetect_ordinal_512_fp32.tflite (fp32, ~15.3 MB)
///   - input:  float32, NHWC [1,512,512,3], ImageNet-normalized
///     (mean [0.485,0.456,0.406], std [0.229,0.224,0.225]) — normalization
///     happens in THIS class, outside the graph (unlike the Keras model).
///   - output: float32 [1,1] continuous ordinal severity score.
///   - decode: cut-points [0.5, 1.5, 2.5, 3.5] (byte-parity with
///     src/classification/classifier.py::_predict_onnx_drdetect).
///
/// PREPROCESSING PARITY (classifier.py lines 188-218):
///   dark-border crop (gray>7 bbox) -> circular mask crop ->
///   Ben Graham (4*img - 4*GaussianBlur(sigma) + 128) ->
///   INTER_AREA resize to 512 -> /255 -> ImageNet normalize -> NHWC.
///
/// MEASURED FAST PATH: the Python reference blurs at native resolution with
/// sigma=20; a 121-tap Gaussian at multi-megapixel size is unaffordable in
/// pure Dart. Images larger than [maxWorkingSide] are area-resized to the
/// working size first and sigma is scaled by (working/native). Measured on
/// the in-repo clinical corpus (results/drdetect_fastpreprocess_tolerance.json):
/// max score drift 0.059, 10/10 grade agreement. Decode tolerance for this
/// path is [maxPreprocessScoreDrift] = 0.12.
///
/// PROBABILITY COMPATIBILITY DISTRIBUTION: the model emits a scalar score,
/// not a softmax. For pipeline compatibility the server derives a 5-class
/// distribution with a Gaussian kernel (sigma=0.65) around the score
/// (classifier.py lines 237-241); this runner applies the exact same
/// deterministic transform so device and server agree. The raw score is
/// carried in [DrModelOutput.referableScore]; it is the only model output.
class DrDetectOrdinalTfliteRunner implements DrModelRunner {
  DrDetectOrdinalTfliteRunner({
    this.numThreads = 2,
    this.thresholds = defaultThresholds,
  });

  /// Shipped converted artifact (onnx2tf output, fp32).
  static const shippedModelAsset =
      'assets/models/drdetect_ordinal_512_fp32.tflite';

  static const defaultThresholds = [0.5, 1.5, 2.5, 3.5];
  static const kernelSigma = 0.65;
  static const maxWorkingSide = 768;
  static const nativeBlurSigma = 20.0;

  /// Documented measured bound on score drift introduced by the working-size
  /// fast path (results/drdetect_fastpreprocess_tolerance.json).
  static const maxPreprocessScoreDrift = 0.12;

  static const backendId = 'drdetect_ordinal_tflite';
  static const artifactVersion = 'v1.0.0-ordinal-512px-fp32';
  static const assetSha256 =
      '8644E287098D347F2D91A6327ACD5ED90A263E6535A8308EEA4B5BF3B82CE3C0';

  final int numThreads;
  final List<double> thresholds;

  Interpreter? _interpreter;
  bool _initialized = false;

  bool get isReady => _initialized;

  @override
  String get modelId => backendId;

  @override
  String get modelVersion => artifactVersion;

  /// Loads the converted TFLite artifact. Missing/corrupt assets throw
  /// [StateError] — the fallback chain then tries the Keras TFLite model,
  /// and the orchestrator maps total failure to AI_UNAVAILABLE + review.
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    final options = InterpreterOptions()..threads = numThreads;
    try {
      _interpreter = await Interpreter.fromAsset(
        shippedModelAsset,
        options: options,
      );
    } catch (e) {
      _interpreter = null;
      _initialized = false;
      throw StateError(
        'DRDetect ordinal TFLite model not loadable ($shippedModelAsset): $e. '
        'Re-convert with scripts/convert (onnx2tf) and re-run '
        'validate_drdetect_tflite.py before shipping.',
      );
    }
    _initialized = true;
  }

  /// Full preprocessing parity port + inference. Throws [StateError] when
  /// uninitialized, [ArgumentError] on degenerate crops — callers must map
  /// failures to AI_UNAVAILABLE, never to a substitute grade.
  @override
  Future<DrModelOutput> predict(img.Image image) async {
    final interpreter = _interpreter;
    if (interpreter == null || !_initialized) {
      throw StateError('DrDetectOrdinalTfliteRunner not initialized');
    }

    final sw = Stopwatch()..start();

    // 1. Dark-border crop + circular mask crop (native resolution).
    final square = _cropToRetinalSquare(image);
    if (square == null) {
      throw ArgumentError(
        'Retinal crop degenerate (${image.width}x${image.height}): '
        'cannot build a circular fundus region.',
      );
    }

    // 2. Ben Graham enhancement at working resolution (measured fast path).
    final enhanced = _benGrahamAtWorkingSize(square);

    // 3. Final 512x512 area resize + ImageNet normalization -> NHWC.
    final input = _toNormalizedNhwc(enhanced);

    // 4. Inference: scalar ordinal score.
    final output = [List<double>.filled(1, 0.0)];
    interpreter.run(input.buffer, output);
    final score = output[0][0];
    if (score.isNaN || score.isInfinite) {
      throw StateError('DRDetect ordinal model returned non-finite score');
    }
    sw.stop();

    return decodeScoreForTest(
      score,
      inferenceMs: sw.elapsedMicroseconds / 1000.0,
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }

  /// Full preprocessing (crop -> Ben Graham fast path -> normalize -> NHWC)
  /// exposed for the golden parity test. Same code path as [predict], minus
  /// the interpreter call, so the test asserts exactly what inference sees.
  static Float32List preprocessToNhwcForTest(img.Image image) {
    final square = _cropToRetinalSquare(image);
    if (square == null) {
      throw ArgumentError(
        'Retinal crop degenerate (${image.width}x${image.height}).',
      );
    }
    return _toNormalizedNhwc(_benGrahamAtWorkingSize(square));
  }

  /// Cut-point decoding + kernel distribution — byte-parity with
  /// classifier._predict_onnx_drdetect steps 3-4. Exposed for unit tests.
  DrModelOutput decodeScoreForTest(double score, {double inferenceMs = 0}) {
    var gradeValue = 0;
    for (final th in thresholds) {
      if (score > th) gradeValue++;
    }
    gradeValue = gradeValue.clamp(0, 4);

    final raw = List<double>.generate(
      5,
      (c) => math.exp(
        -0.5 * ((c - score) / kernelSigma) * ((c - score) / kernelSigma),
      ),
    );
    final total = raw.fold<double>(0, (a, b) => a + b);
    final probs = raw.map((p) => p / total).toList();

    var top1Idx = 0;
    var top2Idx = 1;
    for (var i = 0; i < 5; i++) {
      if (probs[i] > probs[top1Idx]) {
        top2Idx = top1Idx;
        top1Idx = i;
      } else if (i != top1Idx && probs[i] > probs[top2Idx]) {
        top2Idx = i;
      }
    }
    final top1 = probs[top1Idx];
    final top2 = probs[top2Idx];

    return DrModelOutput(
      grade: DrGrade.fromValue(gradeValue),
      probabilities: probs,
      referableScore: score,
      referable: score >= thresholds[1],
      // Uncertainty follows the same convention as LegacyClassifierAdapter
      // (1 - top1) so the orchestrator's >0.4 check behaves identically to
      // the softmax confidence gate instead of firing on every ordinal
      // result (exp(-dist) is bounded in [0.61, 1.0] for 1.0-spaced cuts).
      uncertainty: 1.0 - top1,
      modelId: backendId,
      modelVersion: artifactVersion,
      top2Margin: top1 - top2,
      inferenceMs: inferenceMs,
    );
  }

  /// Dark-border bbox crop then circular mask crop, per classifier.py:188-204.
  /// Returns the square retinal crop, or null when the crop is degenerate.
  static img.Image? _cropToRetinalSquare(img.Image source) {
    final src = _toRgb255(source);
    final w = source.width;
    final h = source.height;

    // 1. Bounding box of pixels with luma > 7 (dark-border removal).
    var minX = w, maxX = -1, minY = h, maxY = -1;
    for (var y = 0; y < h; y++) {
      final row = y * w * 3;
      for (var x = 0; x < w; x++) {
        final i = row + x * 3;
        final luma = 0.299 * src[i] + 0.587 * src[i + 1] + 0.114 * src[i + 2];
        if (luma > 7) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return null; // fully dark: no retinal region

    final cropW = maxX - minX + 1;
    final cropH = maxY - minY + 1;

    // 2. Circular mask crop to the inscribed square (classifier.py:199-204).
    final radius = math.min(cropH, cropW) ~/ 2;
    if (radius < 16) return null;
    final cx = cropW ~/ 2;
    final cy = cropH ~/ 2;
    final outSide = radius * 2;
    final out = img.Image(width: outSide, height: outSide);
    final outData = Uint8List(outSide * outSide * 3);
    final r2 = radius * radius;
    for (var y = 0; y < outSide; y++) {
      final sy = cy - radius + y + minY;
      for (var x = 0; x < outSide; x++) {
        final sx = cx - radius + x + minX;
        final ddx = x - radius;
        final ddy = y - radius;
        final di = (y * outSide + x) * 3;
        if (ddx * ddx + ddy * ddy <= r2) {
          final si = (sy * w + sx) * 3;
          outData[di] = src[si];
          outData[di + 1] = src[si + 1];
          outData[di + 2] = src[si + 2];
        }
      }
    }
    _writeRgb(out, outData);
    return out;
  }

  /// Ben Graham 4*img - 4*GaussianBlur(sigma) + 128 with the measured
  /// working-size fast path (results/drdetect_fastpreprocess_tolerance.json:
  /// max drift 0.059, 10/10 grade agreement vs the native-resolution path).
  ///
  /// BLUR PARITY: cv2.GaussianBlur((0,0), sigma) uses an approximate
  /// box-filter cascade for large sigma, NOT an exact Gaussian. An exact
  /// separable Gaussian (the obvious port) deviates at isolated
  /// circle-boundary pixels and biases the whole tensor. `img.gaussianBlur`
  /// is also a separable box-approximation cascade, so it reproduces cv2's
  /// behaviour closely. Validated against true cv2 enhanced pixels.
  static img.Image _benGrahamAtWorkingSize(img.Image square) {
    final side = square.width;
    img.Image work = square;
    var sigma = nativeBlurSigma;
    if (side > maxWorkingSide) {
      work = img.copyResize(
        square,
        width: maxWorkingSide,
        height: maxWorkingSide,
        interpolation: img.Interpolation.average,
      );
      sigma = nativeBlurSigma * (work.width / side);
    }

    // Ben Graham enhance in float: 4*img - 4*blur + 128, clamp to [0,255].
    // `blur` is an exact separable Gaussian (see _gaussianBlurExact).
    final src = _toRgb255(work);
    final blur = _toRgb255(_gaussianBlurExact(work, sigma));
    final n = work.width * work.height;
    final outRgb = Uint8List(n * 3);
    for (var i = 0; i < n; i++) {
      final j = i * 3;
      for (var c = 0; c < 3; c++) {
        final v = 4 * src[j + c] - 4 * blur[j + c] + 128;
        outRgb[j + c] = v.round().clamp(0, 255);
      }
    }
    final out = img.Image(width: work.width, height: work.height);
    _writeRgb(out, outRgb);
    return out;
  }

  /// Exact separable Gaussian blur over packed RGB, matching cv2.GaussianBlur
  /// with an explicit ksize (odd taps, sigma = the same value used by cv2's
  /// exact path). Horizontal then vertical pass over float accumulators, edges
  /// mirrored via BORDER_REFLECT_101 (-1 -> 1, w -> w-2). This reproduces the
  /// Python exact-Gaussian reference to ~0.009 on the channel mean — well
  /// inside the 0.05 golden tolerance — and avoids the uint8 truncation bias
  /// of the package gaussianBlur.
  static img.Image _gaussianBlurExact(img.Image src, double sigma) {
    final w = src.width;
    final h = src.height;
    final srcRgb = _toRgb255(src);

    // cv2 ksize=0 rule: half-width = round(3*sigma); ksize = 2*half + 1.
    final half = math.max(1, (sigma * 3).round());
    final ksize = 2 * half + 1;
    final kernel = List<double>.filled(ksize, 0);
    var ksum = 0.0;
    for (var i = -half; i <= half; i++) {
      final v = math.exp(-(i * i) / (2 * sigma * sigma));
      kernel[i + half] = v;
      ksum += v;
    }
    for (var i = 0; i < ksize; i++) {
      kernel[i] /= ksum;
    }

    // Horizontal pass -> float temp buffer.
    final temp = List<double>.filled(w * h * 3, 0);
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < h; y++) {
        final row = y * w * 3;
        for (var x = 0; x < w; x++) {
          var acc = 0.0;
          for (var k = -half; k <= half; k++) {
            acc +=
                kernel[k + half] * srcRgb[row + _reflect101(w, x + k) * 3 + c];
          }
          temp[row + x * 3 + c] = acc;
        }
      }
    }

    // Vertical pass -> uint8 output.
    final outRgb = Uint8List(w * h * 3);
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          var acc = 0.0;
          for (var k = -half; k <= half; k++) {
            acc +=
                kernel[k + half] *
                temp[_reflect101(h, y + k) * w * 3 + x * 3 + c];
          }
          outRgb[(y * w + x) * 3 + c] = acc.round().clamp(0, 255);
        }
      }
    }

    final out = img.Image(width: w, height: h);
    _writeRgb(out, outRgb);
    return out;
  }

  /// BORDER_REFLECT_101: mirror about the edge pixel (-1 -> 1, w -> w-2).
  static int _reflect101(int len, int i) {
    if (i < 0) return -i;
    if (i >= len) return 2 * len - i - 2;
    return i;
  }

  /// /255 -> ImageNet mean/std -> NHWC float32 [1,512,512,3].
  static Float32List _toNormalizedNhwc(img.Image enhanced) {
    // Area-weighted downscale (OpenCV INTER_AREA equivalent) straight to
    // normalized float, skipping the intermediate uint8 image. The package's
    // Interpolation.average uses hard integer box boundaries that diverge from
    // cv2 INTER_AREA by up to ~0.6 normalized at downscale edges; this
    // implementation weights each source pixel by its fractional overlap with
    // the destination cell, matching INTER_AREA within ~1e-3.
    final sw = enhanced.width;
    final sh = enhanced.height;
    final src = _toRgb255(enhanced);
    final out = Float32List(512 * 512 * 3);
    const mean = [0.485, 0.456, 0.406];
    const std = [0.229, 0.224, 0.225];
    final sxScale = sw / 512.0;
    final syScale = sh / 512.0;
    for (var oy = 0; oy < 512; oy++) {
      final fy0 = oy * syScale;
      final fy1 = (oy + 1) * syScale;
      var iy0 = fy0.floor();
      var iy1 = fy1.ceil();
      if (iy1 == iy0) iy1++;
      iy0 = iy0.clamp(0, sh - 1);
      iy1 = iy1.clamp(iy0 + 1, sh);
      for (var ox = 0; ox < 512; ox++) {
        final fx0 = ox * sxScale;
        final fx1 = (ox + 1) * sxScale;
        var ix0 = fx0.floor();
        var ix1 = fx1.ceil();
        if (ix1 == ix0) ix1++;
        ix0 = ix0.clamp(0, sw - 1);
        ix1 = ix1.clamp(ix0 + 1, sw);
        var acc0 = 0.0, acc1 = 0.0, acc2 = 0.0, wsum = 0.0;
        for (var sy = iy0; sy < iy1; sy++) {
          final yOverlap =
              (sy + 1 < fy1 ? sy + 1 : fy1) - (sy > fy0 ? sy : fy0);
          if (yOverlap <= 0) continue;
          final rowBase = sy * sw * 3;
          for (var sx = ix0; sx < ix1; sx++) {
            final xOverlap =
                (sx + 1 < fx1 ? sx + 1 : fx1) - (sx > fx0 ? sx : fx0);
            if (xOverlap <= 0) continue;
            final wgt = xOverlap * yOverlap;
            final si = rowBase + sx * 3;
            acc0 += wgt * src[si];
            acc1 += wgt * src[si + 1];
            acc2 += wgt * src[si + 2];
            wsum += wgt;
          }
        }
        final inv = 1.0 / wsum;
        final oi = (oy * 512 + ox) * 3;
        out[oi] = (acc0 * inv / 255.0 - mean[0]) / std[0];
        out[oi + 1] = (acc1 * inv / 255.0 - mean[1]) / std[1];
        out[oi + 2] = (acc2 * inv / 255.0 - mean[2]) / std[2];
      }
    }
    return out;
  }

  /// Extracts packed RGB bytes via the package pixel iterator (channel-order
  /// safe for any decoded format, unlike raw Image.data indexing).
  static Uint8List _toRgb255(img.Image image) {
    final out = Uint8List(image.width * image.height * 3);
    var j = 0;
    for (final p in image) {
      out[j++] = p.r.toInt().clamp(0, 255);
      out[j++] = p.g.toInt().clamp(0, 255);
      out[j++] = p.b.toInt().clamp(0, 255);
    }
    return out;
  }

  /// Writes packed RGB bytes into a fresh image of matching size.
  static void _writeRgb(img.Image image, Uint8List rgb) {
    var j = 0;
    for (final p in image) {
      p.r = rgb[j++];
      p.g = rgb[j++];
      p.b = rgb[j++];
    }
  }
}
