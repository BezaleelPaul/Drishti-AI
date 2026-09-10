class PatientModel {
  final String patientId;
  final String name;
  final int age;
  final String gender;
  final String phone;
  final String abhaId;
  final String village;
  final String knownDiabetes;
  final double? diabetesDurationYears;
  final double? hba1c;
  final double? fastingGlucose;
  final double? bmi;
  final bool familyHistory;

  PatientModel({
    required this.patientId,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.abhaId,
    required this.village,
    required this.knownDiabetes,
    this.diabetesDurationYears,
    this.hba1c,
    this.fastingGlucose,
    this.bmi,
    this.familyHistory = false,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      patientId: json['patient_id'] ?? 'PT-UNKNOWN',
      name: json['name'] ?? '',
      age: json['age'] ?? 45,
      gender: json['gender'] ?? 'Unknown',
      phone: json['phone'] ?? '',
      abhaId: json['abha_id'] ?? '',
      village: json['village'] ?? '',
      knownDiabetes: json['known_diabetes'] ?? 'Unknown',
      diabetesDurationYears: (json['diabetes_duration_years'] as num?)?.toDouble(),
      hba1c: (json['hba1c'] as num?)?.toDouble(),
      fastingGlucose: (json['fasting_glucose'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      familyHistory: json['family_history'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_id': patientId,
      'name': name,
      'age': age,
      'gender': gender,
      'phone': phone,
      'abha_id': abhaId,
      'village': village,
      'known_diabetes': knownDiabetes,
      'diabetes_duration_years': diabetesDurationYears,
      'hba1c': hba1c,
      'fasting_glucose': fastingGlucose,
      'bmi': bmi,
      'family_history': familyHistory,
    };
  }
}

class DiabetesRiskModel {
  final double riskScore;
  final String riskLevel;
  final String pathway;
  final List<String> clinicalRationale;
  final String actionRecommendation;
  final String patientFriendlyGuidance;

  DiabetesRiskModel({
    required this.riskScore,
    required this.riskLevel,
    required this.pathway,
    required this.clinicalRationale,
    required this.actionRecommendation,
    required this.patientFriendlyGuidance,
  });

  factory DiabetesRiskModel.fromJson(Map<String, dynamic> json) {
    return DiabetesRiskModel(
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] ?? 'LOW',
      pathway: json['pathway'] ?? 'ROUTINE_MONITORING',
      clinicalRationale: List<String>.from(json['clinical_rationale'] ?? []),
      actionRecommendation: json['action_recommendation'] ?? '',
      patientFriendlyGuidance: json['patient_friendly_guidance'] ?? '',
    );
  }
}

class RetinalQualityModel {
  final String qualityGrade; // 'GOOD', 'BORDERLINE', 'BAD'
  final double qualityScore;
  final bool isReliable;
  final List<String> rejectionReasons;
  final String? suspectedClinicalCause;
  final String operatorAction;
  final List<String> recaptureTips;
  final String audioGuidanceHindi;

  RetinalQualityModel({
    required this.qualityGrade,
    required this.qualityScore,
    required this.isReliable,
    required this.rejectionReasons,
    this.suspectedClinicalCause,
    required this.operatorAction,
    required this.recaptureTips,
    required this.audioGuidanceHindi,
  });

  factory RetinalQualityModel.fromJson(Map<String, dynamic> json) {
    return RetinalQualityModel(
      qualityGrade: json['quality_grade'] ?? 'BORDERLINE',
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0.5,
      isReliable: json['is_reliable'] ?? false,
      rejectionReasons: List<String>.from(json['rejection_reasons'] ?? []),
      suspectedClinicalCause: json['suspected_clinical_cause'],
      operatorAction: json['operator_action'] ?? '',
      recaptureTips: List<String>.from(json['recapture_tips'] ?? []),
      audioGuidanceHindi: json['audio_guidance_hindi'] ?? 'कृपया पुनः प्रयास करें।',
    );
  }
}

class ScreeningAnalysisModel {
  final String screeningId;
  final String patientId;
  final String eyeSide;
  final String cameraProfile;
  final String qualityGrade;
  final double qualityScore;
  final bool qualityPassed;
  final List<String> rejectionReasons;
  final int? drGrade;
  final String? drLabel;
  final double? predictionScore;
  final bool isReferable;
  final bool requiresHumanReview;
  final String? humanReviewType;
  final String? humanReviewReason;
  final String originalImageUrl;
  final String? gradcamOverlayUrl;
  final String? gradcamTargetLayer;
  final String actionRecommendation;
  final String plainLanguageAdvice;
  final String smsReferralSlip;
  final Map<String, dynamic>? biomarkers;

  ScreeningAnalysisModel({
    required this.screeningId,
    required this.patientId,
    required this.eyeSide,
    required this.cameraProfile,
    required this.qualityGrade,
    required this.qualityScore,
    required this.qualityPassed,
    required this.rejectionReasons,
    this.drGrade,
    this.drLabel,
    this.predictionScore,
    required this.isReferable,
    required this.requiresHumanReview,
    this.humanReviewType,
    this.humanReviewReason,
    required this.originalImageUrl,
    this.gradcamOverlayUrl,
    this.gradcamTargetLayer,
    required this.actionRecommendation,
    required this.plainLanguageAdvice,
    required this.smsReferralSlip,
    this.biomarkers,
  });

  factory ScreeningAnalysisModel.fromJson(Map<String, dynamic> json) {
    return ScreeningAnalysisModel(
      screeningId: json['screening_id'] ?? 'SCR-DEMO',
      patientId: json['patient_id'] ?? '',
      eyeSide: json['eye_side'] ?? 'Right',
      cameraProfile: json['camera_profile'] ?? 'Generic',
      qualityGrade: json['quality_grade'] ?? 'GOOD',
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0.9,
      qualityPassed: json['quality_passed'] ?? true,
      rejectionReasons: List<String>.from(json['rejection_reasons'] ?? []),
      drGrade: json['dr_grade'],
      drLabel: json['dr_label'],
      predictionScore: (json['prediction_score'] as num?)?.toDouble(),
      isReferable: json['is_referable'] ?? false,
      requiresHumanReview: json['requires_human_review'] ?? false,
      humanReviewType: json['human_review_type'],
      humanReviewReason: json['human_review_reason'],
      originalImageUrl: json['original_image_url'] ?? '',
      gradcamOverlayUrl: json['gradcam_overlay_url'],
      gradcamTargetLayer: json['gradcam_target_layer'],
      actionRecommendation: json['action_recommendation'] ?? '',
      plainLanguageAdvice: json['plain_language_advice'] ?? json['patient_plain_language_summary'] ?? '',
      smsReferralSlip: json['sms_referral_slip'] ?? '',
      biomarkers: json['biomarkers'] as Map<String, dynamic>?,
    );
  }
}
