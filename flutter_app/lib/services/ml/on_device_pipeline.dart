import 'dart:typed_data';

import '../../models/screening_models.dart';
import 'dr_classifier.dart';
import 'model_runner.dart';
import 'pipeline_schema.dart';
import 'quality_gate.dart';
import 'quality_thresholds.dart';
import 'screening_orchestrator.dart';

/// Bridges the on-device ML layer into the app's existing [ScreeningAnalysisModel] contract.
/// Defaults to the benchmark-winning DRDetect Ordinal Regression model.
class OnDevicePipeline {
  OnDevicePipeline({
    DrModelRunner? modelRunner,
    DrClassifierDart? classifier,
  }) : _modelRunner = modelRunner ?? (classifier != null ? LegacyClassifierAdapter(classifier) : DrDetectRunner()),
       _orchestrator = ScreeningOrchestrator(modelRunner: modelRunner, classifier: classifier);

  final DrModelRunner _modelRunner;
  DrModelRunner get modelRunner => _modelRunner;
  final ScreeningOrchestrator _orchestrator;
  bool _initTried = false;

  /// True when the on-device model runner is initialized and usable.
  Future<bool> ensureReady() async {
    if (_initTried) return true;
    _initTried = true;
    try {
      await _orchestrator.initialize();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs ONLY the on-device quality gate (Node 2) — used by the capture
  /// screen so image usability is checked with airplane mode on.
  RetinalQualityModel? checkQualityOnDevice(Uint8List imageBytes) {
    try {
      final canonical = decodeCanonicalRgb(imageBytes);
      final res = const QualityGateDart().assess(
        canonical.bytes,
        canonical.width,
        canonical.height,
      );
      return _toQualityModel(res);
    } on FormatException {
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

  /// Returns the on-device result, or null when the artifact is unavailable.
  Future<ScreeningAnalysisModel?> analyze({
    required Uint8List imageBytes,
    required String patientId,
    required String eyeSide,
    required String cameraProfile,
    int recaptureAttemptCount = 0,
  }) async {
    if (!await ensureReady()) return null;
    final record = await _orchestrator.processImage(
      imageBytes,
      recaptureAttemptCount: recaptureAttemptCount,
    );
    return _toAnalysisModel(record, patientId, eyeSide, cameraProfile);
  }

  /// Maps ScreeningRecordDart -> ScreeningAnalysisModel.
  ScreeningAnalysisModel _toAnalysisModel(
    ScreeningRecordDart record,
    String patientId,
    String eyeSide,
    String cameraProfile,
  ) {
    final dr = record.drPrediction;
    final conf = record.confidence;
    final metrics = record.qualityMetrics;

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
      isOffline: false,
      isFromFallback: false,
      errorCode: record.errorCode?.code,
    );
  }
}
