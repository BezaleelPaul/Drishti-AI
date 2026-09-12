import 'dart:typed_data';
import '../../models/screening_models.dart';

/// Shared mutable state for the Figma 7-step screening flow
/// (register → capture → ai-analysis → ai-result → specialist →
/// referral → report). Created at registration, passed down each step.
class FlowState {
  PatientModel patient;
  DiabetesRiskModel? risk;
  Uint8List? imageBytes;
  String filename;
  String cameraProfile;
  String eyeSide; // 'Right' | 'Left'
  RetinalQualityModel? quality;
  ScreeningAnalysisModel? analysis;

  /// Specialist verdict: 'CONFIRM' | 'CHANGE' | 'REEXAMINE'.
  String? verdict;
  int? correctedGrade;
  String specialistNotes;
  bool referralSent;

  FlowState({
    required this.patient,
    this.risk,
    this.imageBytes,
    this.filename = '2_clear_eye_normal.jpg',
    this.cameraProfile = 'Remidio FOP (Smartphone Handheld)',
    this.eyeSide = 'Right',
    this.quality,
    this.analysis,
    this.verdict,
    this.correctedGrade,
    this.specialistNotes = '',
    this.referralSent = false,
  });
}
