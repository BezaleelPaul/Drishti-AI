import 'dart:typed_data';

import '../../models/screening_models.dart';
import 'dr_classifier.dart';
import 'pipeline_schema.dart';
import 'quality_gate.dart';
import 'quality_thresholds.dart';
import 'screening_orchestrator.dart';

/// Bridges the on-device ML layer (Dart ports of the Python pipeline) into
/// the app's existing [ScreeningAnalysisModel] contract so every screen
/// keeps working unchanged, offline or online.
///
/// Priority order (offline-first, never fake):
///   1. On-device inference (quality gate + int8 TFLite classifier).
///   2. If the on-device model artifact is missing/unloadable -> server
///      analysis (existing LAN laptop path).
///   3. If the server is unreachable -> PENDING_SYNC queue entry (no grade).
class OnDevicePipeline {
  OnDevicePipeline({DrClassifierDart? classifier})
    : _classifier = classifier ?? DrClassifierDart(),
      _orchestrator = ScreeningOrchestrator(classifier: classifier);

  final DrClassifierDart _classifier;
  final ScreeningOrchestrator _orchestrator;
  bool _initTried = false;

  /// True when the on-device model artifact is loaded and usable.
  Future<bool> ensureReady() async {
    if (_classifier.isReady) return true;
    if (_initTried) return false;
    _initTried = true;
    try {
      await _orchestrator.initialize();
      return true;
    } on StateError {
      return false;
    }
  }

  /// Runs ONLY the on-device quality gate (Node 2) — used by the capture
  /// screen so image usability is checked with airplane mode on. Returns
  /// null when the gate cannot run (caller falls back to the server).
  RetinalQualityModel? checkQualityOnDevice(Uint8List imageBytes) {
    if (!_classifier.isReady) return null;
    try {
      final canonical = decodeCanonicalRgb(imageBytes);
      final res = const QualityGateDart().assess(
        canonical.bytes,
        canonical.width,
        canonical.height,
      );
      return _toQualityModel(res);
    } on FormatException {
      // Fail closed: a frame that cannot be decoded is ungradable.
      return _toQualityModel(
        const QualityAssessmentResult(
          grade: QualityGrade.BAD,
          isReliable: false,
          reasons: [QualityReason.nonFundusOrCorrupt],
          details: 'Image could not be decoded',
          errorCode: PipelineErrorCode.imgInvalid,
        ),
      );
    }
  }

  RetinalQualityModel _toQualityModel(QualityAssessmentResult res) {
    final tips = <String>[];
    if (res.reasons.contains(QualityReason.severeBlur)) {
      tips.add('Hold the camera steady and refocus');
    }
    if (res.reasons.contains(QualityReason.inadequateIllumination)) {
      tips.add('Increase illumination / check pupil dilation');
    }
    if (res.reasons.contains(QualityReason.overexposure)) {
      tips.add('Reduce glare and flash intensity');
    }
    if (res.reasons.contains(QualityReason.insufficientFieldOfView)) {
      tips.add('Center the retina inside the frame');
    }
    return RetinalQualityModel(
      qualityGrade: res.grade.name,
      qualityScore: res.metrics.mlQualityScore,
      isReliable: res.isReliable,
      rejectionReasons: res.reasons.map((r) => r.display).toList(),
      suspectedClinicalCause: res.suspectedClinicalCause,
      operatorAction: res.grade == QualityGrade.BAD
          ? 'Recapture the image. Do not display a DR grade for an image '
                'that fails the reliability gate.'
          : res.grade == QualityGrade.BORDERLINE
          ? 'Recapture recommended for a borderline image.'
          : 'Image certified as reliable. Proceed to analysis.',
      recaptureTips: tips,
      audioGuidanceHindi: 'कृपया पुनः प्रयास करें।',
    );
  }

  /// Returns the on-device result, or null when the artifact is unavailable
  /// (caller falls back to the server path).
  Future<ScreeningAnalysisModel?> analyze({
    required Uint8List imageBytes,
    required String patientId,
    required String eyeSide,
    required String cameraProfile,
    int recaptureAttemptCount = 0,
  }) async {
    if (!await ensureReady()) return null;
    final record = _orchestrator.processImage(
      imageBytes,
      recaptureAttemptCount: recaptureAttemptCount,
    );
    return _toAnalysisModel(record, patientId, eyeSide, cameraProfile);
  }

  /// Maps ScreeningRecordDart -> ScreeningAnalysisModel (the wire-shaped
  /// model the UI already consumes). Every field stays honest: no value is
  /// fabricated when the pipeline did not produce it.
  ScreeningAnalysisModel _toAnalysisModel(
    ScreeningRecordDart record,
    String patientId,
    String eyeSide,
    String cameraProfile,
  ) {
    final dr = record.drPrediction;
    final conf = record.confidence;
    final metrics = record.qualityMetrics;

    // X-0 rule mirrors ScreeningRecordDart.referableFlag, re-derived here so
    // the UI model carries the adopted operating point (held-out t*=0.09).
    final referableMass = dr == null
        ? 0.0
        : dr.probabilities.sublist(2).fold<double>(0.0, (a, b) => a + b);
    final isReferable =
        dr != null &&
        (dr.predictedGrade.isReferable ||
            referableMass >= kReferableMassThreshold);

    return ScreeningAnalysisModel(
      screeningId: 'LOC-${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      eyeSide: eyeSide,
      cameraProfile: cameraProfile,
      qualityGrade: record.qualityGrade.name,
      qualityScore: metrics?.mlQualityScore ?? 0.0,
      qualityPassed: record.qualityGrade == QualityGrade.GOOD,
      rejectionReasons: record.rejectionReasons,
      drGrade: dr?.predictedGrade.value,
      drLabel: dr?.predictedGrade.label,
      predictionScore: dr?.confidence,
      isReferable: isReferable,
      requiresHumanReview: record.humanReviewRequired,
      humanReviewType: record.humanReviewType == HumanReviewType.NONE
          ? null
          : record.humanReviewType.name,
      humanReviewReason: record.humanReviewReason,
      originalImageUrl: '',
      gradcamOverlayUrl: null,
      gradcamTargetLayer: null,
      modelBackend: record.modelBackend,
      actionRecommendation: record.action,
      plainLanguageAdvice: record.action,
      smsReferralSlip: '',
      probabilities: dr?.probabilities,
      biomarkers: conf == null
          ? null
          : {
              'confidence_flag_count': conf.flags.length,
              'is_ambiguous': conf.isAmbiguous,
              'is_high_risk': conf.isHighRisk,
              if (record.inferenceMs != null)
                'inference_time_ms': record.inferenceMs,
            },
      // On-device results are REAL AI output (not the offline placeholder),
      // so isOffline stays false; model_backend tells the truth about where
      // the numbers came from.
      isOffline: false,
      isFromFallback: false,
      errorCode: record.errorCode?.code,
    );
  }
}
