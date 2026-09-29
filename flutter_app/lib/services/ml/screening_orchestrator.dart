import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'dr_classifier.dart';
import 'confidence_evaluator.dart';
import 'pipeline_schema.dart';
import 'quality_gate.dart';
import 'quality_thresholds.dart';

/// On-device port of src/pipeline/router.py (Nodes 1-11).
///
/// Deliberate v1 difference (documented in docs/TEAM_PLAN_NEXT_UPDATE.md):
/// BORDERLINE images are NOT landmark-reassessed on-device (the OpenCV
/// structure segmenter is a P1/P2 port); a borderline capture follows the
/// FAILED branch — recapture up to the cap, then OPERATOR_LEVEL review.
/// This is the conservative direction of the Python logic: it can only
/// reduce automated throughput, never fabricate a grade.
class ScreeningOrchestrator {
  ScreeningOrchestrator({
    DrClassifierDart? classifier,
    QualityGateDart? qualityGate,
  }) : _classifier = classifier ?? DrClassifierDart(),
       _gate = qualityGate ?? const QualityGateDart();

  final DrClassifierDart _classifier;
  final QualityGateDart _gate;

  Future<void> initialize() => _classifier.initialize();

  /// Full on-device screening for one capture.
  ScreeningRecordDart processImage(
    Uint8List encodedBytes, {
    int recaptureAttemptCount = 0,
  }) {
    final attempt = recaptureAttemptCount < 0 ? 0 : recaptureAttemptCount;

    // Node 1: decode ONCE to canonical RGB (shared with every stage).
    final img.Image decoded;
    try {
      final raw = img.decodeImage(encodedBytes);
      if (raw == null) {
        throw const FormatException('Could not decode image');
      }
      decoded = raw;
    } on FormatException {
      return ScreeningRecordDart(
        imagePath: 'capture',
        qualityGrade: QualityGrade.BAD,
        qualityStatus: 'Unreliable',
        rejectionReasons: [QualityReason.nonFundusOrCorrupt.display],
        recaptureAttemptCount: attempt,
        reassessmentOutcome: ReassessmentOutcome.NOT_APPLICABLE,
        errorCode: PipelineErrorCode.imgInvalid,
        action: 'Image could not be decoded. Recapture the image.',
      );
    }

    CanonicalImage canonical;
    try {
      canonical = canonicalRgbFromDecoded(decoded);
    } on FormatException {
      return ScreeningRecordDart(
        imagePath: 'capture',
        qualityGrade: QualityGrade.BAD,
        qualityStatus: 'Unreliable',
        rejectionReasons: [QualityReason.nonFundusOrCorrupt.display],
        recaptureAttemptCount: attempt,
        reassessmentOutcome: ReassessmentOutcome.NOT_APPLICABLE,
        errorCode: PipelineErrorCode.imgInvalid,
        action: 'Invalid image dimensions. Recapture the image.',
      );
    }

    // Node 2: quality gate (Model 1).
    final quality = _gate.assess(
      canonical.bytes,
      canonical.width,
      canonical.height,
    );

    // Node 3c: BAD path.
    if (quality.grade == QualityGrade.BAD) {
      if (attempt >= kMaxRecaptureCap) {
        return ScreeningRecordDart(
          imagePath: 'capture',
          qualityGrade: QualityGrade.BAD,
          qualityStatus: 'Unreliable (Retry limit reached)',
          rejectionReasons: quality.reasons.map((r) => r.display).toList(),
          recaptureAttemptCount: attempt,
          reassessmentOutcome: ReassessmentOutcome.NOT_APPLICABLE,
          humanReviewRequired: true,
          humanReviewType: HumanReviewType.OPERATOR_LEVEL,
          humanReviewReason:
              'Recapture cap of $kMaxRecaptureCap attempts reached. '
              'Operator/clinician must inspect patient eye directly.',
          action:
              'Recapture cap reached ($attempt/$kMaxRecaptureCap). '
              'Escalate to supervising clinician for on-site physical evaluation.',
          qualityMetrics: quality.metrics,
          errorCode: quality.errorCode ?? PipelineErrorCode.imgUntgradable,
        );
      }
      return ScreeningRecordDart(
        imagePath: 'capture',
        qualityGrade: QualityGrade.BAD,
        qualityStatus: 'Unreliable',
        rejectionReasons: quality.reasons.map((r) => r.display).toList(),
        recaptureAttemptCount: attempt + 1,
        reassessmentOutcome: ReassessmentOutcome.NOT_APPLICABLE,
        action:
            'Recapture image. Do not display a DR grade for an image '
            'that fails the reliability gate.',
        qualityMetrics: quality.metrics,
        errorCode: quality.errorCode ?? PipelineErrorCode.imgUntgradable,
      );
    }

    // Node 3b/4/5: BORDERLINE — conservative on-device mode (no landmark
    // reassessment in v1): recapture, escalate at cap. No grade is produced.
    if (quality.grade == QualityGrade.BORDERLINE) {
      if (attempt >= kMaxRecaptureCap) {
        return ScreeningRecordDart(
          imagePath: 'capture',
          qualityGrade: QualityGrade.BORDERLINE,
          qualityStatus: 'Unreliable (Retry limit reached)',
          rejectionReasons: quality.reasons.map((r) => r.display).toList(),
          recaptureAttemptCount: attempt,
          reassessmentOutcome: ReassessmentOutcome.FAILED,
          humanReviewRequired: true,
          humanReviewType: HumanReviewType.OPERATOR_LEVEL,
          humanReviewReason:
              'Recapture cap of $kMaxRecaptureCap attempts '
              'reached. Borderline image; operator/clinician must inspect '
              'patient eye directly.',
          action:
              'Recapture cap reached ($attempt/$kMaxRecaptureCap). '
              'Escalate to supervising clinician. Image does NOT proceed to '
              'DR Classification.',
          qualityMetrics: quality.metrics,
          errorCode: PipelineErrorCode.imgUntgradable,
        );
      }
      return ScreeningRecordDart(
        imagePath: 'capture',
        qualityGrade: QualityGrade.BORDERLINE,
        qualityStatus: 'Unreliable (Failed Reassessment)',
        rejectionReasons: quality.reasons.map((r) => r.display).toList(),
        recaptureAttemptCount: attempt + 1,
        reassessmentOutcome: ReassessmentOutcome.FAILED,
        humanReviewRequired: true,
        humanReviewType: HumanReviewType.OPERATOR_LEVEL,
        humanReviewReason:
            'Borderline image requires recapture (on-device conservative mode).',
        action:
            'Reassessment pending. Recapture attempt '
            '#${attempt + 1}/$kMaxRecaptureCap. Image does NOT proceed to '
            'DR Classification.',
        qualityMetrics: quality.metrics,
        errorCode: PipelineErrorCode.imgUntgradable,
      );
    }

    // Node 6→7: reliable image — DR classification (Model 2) on bicubic
    // 224x224 resize of the ORIGINAL canonical pixels. Measured (E-2):
    // the stopwatch covers resize + pixel copy + TFLite run so the number
    // shown to the operator is the honest end-to-end model cost.
    final DrClassificationResult drResult;
    var inferenceMs = 0.0;
    final sw = Stopwatch()..start();
    try {
      final resized = img.copyResize(
        decoded,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.cubic,
      );
      final rgb224 = Uint8List(224 * 224 * 3);
      var j = 0;
      for (final p in resized) {
        rgb224[j++] = p.r.toInt().clamp(0, 255);
        rgb224[j++] = p.g.toInt().clamp(0, 255);
        rgb224[j++] = p.b.toInt().clamp(0, 255);
      }
      drResult = _classifier.classify(rgb224);
      sw.stop();
      inferenceMs = sw.elapsedMicroseconds / 1000.0;
    } on StateError {
      return ScreeningRecordDart(
        imagePath: 'capture',
        qualityGrade: quality.grade,
        qualityStatus: 'AI unavailable',
        rejectionReasons: const [],
        recaptureAttemptCount: attempt,
        reassessmentOutcome: ReassessmentOutcome.NOT_APPLICABLE,
        humanReviewRequired: true,
        humanReviewType: HumanReviewType.OPERATOR_LEVEL,
        humanReviewReason: 'On-device DR model unavailable: mandatory review.',
        action: 'AI unavailable. Route capture for human review.',
        qualityMetrics: quality.metrics,
        errorCode: PipelineErrorCode.aiUnavailable,
      );
    } on ArgumentError {
      return ScreeningRecordDart(
        imagePath: 'capture',
        qualityGrade: quality.grade,
        qualityStatus: 'AI error',
        rejectionReasons: const [],
        recaptureAttemptCount: attempt,
        reassessmentOutcome: ReassessmentOutcome.NOT_APPLICABLE,
        humanReviewRequired: true,
        humanReviewType: HumanReviewType.OPERATOR_LEVEL,
        humanReviewReason: 'Classifier output invalid: mandatory review.',
        action: 'AI output rejected. Route capture for human review.',
        qualityMetrics: quality.metrics,
        errorCode: PipelineErrorCode.aiUnavailable,
      );
    }

    // Node 8: confidence / uncertainty.
    final confidence = const ConfidenceEvaluatorDart().evaluate(drResult);

    // Node 10/11: referable (argmax grade >= 2 OR mass >= t*=0.09) mandates
    // clinician review even when confident; X-0 operating point applied.
    final referableMass = drResult.probabilities
        .sublist(2)
        .fold<double>(0.0, (a, b) => a + b);
    final referableReview =
        drResult.predictedGrade.isReferable ||
        referableMass >= kReferableMassThreshold;
    final humanReviewRequired =
        confidence.requiresHumanReview || referableReview;
    final reviewType = humanReviewRequired
        ? HumanReviewType.CLINICAL_LEVEL
        : HumanReviewType.NONE;
    final flags = List<String>.from(confidence.flags);
    if (referableReview && !confidence.requiresHumanReview) {
      flags.add(
        'Referable ${drResult.predictedGrade.label} requires clinician confirmation per triage protocol',
      );
    }

    final uncertain = !confidence.isConfident || confidence.isAmbiguous;
    final errorCode = uncertain ? PipelineErrorCode.aiLowConfidence : null;

    String actionText;
    if (uncertain && !referableReview) {
      actionText =
          'AI confidence below the reliability threshold: no automated '
          'result released. Image routed for mandatory clinician review.';
    } else if (drResult.predictedGrade.value == 0) {
      actionText = humanReviewRequired
          ? 'Routine annual screening recommended. Low confidence / ambiguity '
                'flagged for clinical verification.'
          : 'Routine screening: No DR detected. Rescreen in 12 months.';
    } else if (drResult.predictedGrade.value == 1) {
      actionText = humanReviewRequired
          ? 'Mild NPDR flagged for clinician over-read. Follow-up per clinical guidelines.'
          : 'Mild NPDR detected. Routine 6-12 month follow-up recommended.';
    } else {
      actionText =
          'Refer for ophthalmic evaluation / human review per workflow.';
    }

    return ScreeningRecordDart(
      imagePath: 'capture',
      qualityGrade: quality.grade,
      qualityStatus: 'Reliable',
      rejectionReasons: const [],
      recaptureAttemptCount: attempt,
      reassessmentOutcome: ReassessmentOutcome.NOT_APPLICABLE,
      drPrediction: drResult,
      confidence: confidence,
      humanReviewRequired: humanReviewRequired,
      humanReviewType: reviewType,
      humanReviewReason: humanReviewRequired && flags.isNotEmpty
          ? flags.join(' | ')
          : null,
      action: actionText,
      qualityMetrics: quality.metrics,
      errorCode: errorCode,
      inferenceMs: inferenceMs,
    );
  }
}
