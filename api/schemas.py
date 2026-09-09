"""
Pydantic Schemas for Netra-AI FastAPI REST API.
Complies with clinical guidelines, plain-language patient summaries,
and ABDM tele-ophthalmology requirements.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


# -----------------------------------------------------------------------------
# 1. Patient Schemas
# -----------------------------------------------------------------------------
class PatientBase(BaseModel):
    name: str = Field(..., example="Ramesh Kumar")
    age: int = Field(..., ge=1, le=120, example=54)
    gender: str = Field(..., example="Male")
    phone: Optional[str] = Field(None, example="+91 98451 22340")
    abha_id: Optional[str] = Field(None, example="91-4521-8890-3321")
    village: Optional[str] = Field(None, example="Shivaji Nagar, PHC Bhor")
    screening_centre: Optional[str] = Field(None, example="Bhor Rural Health Sub-Centre")

    # Diabetes Context
    known_diabetes: str = Field("Unknown", example="Yes")  # 'Yes', 'No', 'Unknown'
    diabetes_duration_years: Optional[float] = Field(None, example=6.0)
    hba1c: Optional[float] = Field(None, example=8.2)
    fasting_glucose: Optional[float] = Field(None, example=165.0)
    blood_pressure: Optional[str] = Field(None, example="138/86")

    # Upstream Risk Factors
    bmi: Optional[float] = Field(None, example=28.4)
    family_history: bool = Field(False, example=True)
    physical_activity: str = Field("Moderate", example="Sedentary")
    symptoms: List[str] = Field(default_factory=list, example=["Blurry vision", "Mild fatigue"])


class PatientCreate(PatientBase):
    patient_id: Optional[str] = Field(None, example="PT-2026-101")


class PatientResponse(PatientBase):
    patient_id: str
    created_at: str

    class Config:
        from_attributes = True


class PatientListResponse(BaseModel):
    total: int
    patients: List[PatientResponse]


# -----------------------------------------------------------------------------
# 2. Diabetes Risk Screening Schemas
# -----------------------------------------------------------------------------
class DiabetesRiskRequest(BaseModel):
    patient_id: Optional[str] = None
    age: int = Field(..., example=54)
    gender: str = Field(..., example="Male")
    bmi: float = Field(..., example=28.4)
    family_history: bool = Field(..., example=True)
    physical_activity: str = Field("Sedentary", example="Sedentary")
    symptoms: List[str] = Field(default_factory=list, example=["Blurry vision"])
    hba1c: Optional[float] = Field(None, example=8.2)
    fasting_glucose: Optional[float] = Field(None, example=165.0)
    known_diabetes_years: Optional[float] = Field(None, example=6.0)


class DiabetesRiskResponse(BaseModel):
    risk_score: float = Field(..., example=84.0)  # 0 to 100
    risk_level: str = Field(..., example="HIGH")   # 'LOW', 'MODERATE', 'HIGH'
    pathway: str = Field(..., example="RETINAL_SCREENING_INDICATED")
    clinical_rationale: List[str] = Field(default_factory=list)
    action_recommendation: str = Field(..., example="Retinal imaging indicated for Diabetic Retinopathy screening.")
    patient_friendly_guidance: str = Field(
        ...,
        example="The assessment indicates elevated risk factors. Clinical testing and retinal screening are recommended."
    )


# -----------------------------------------------------------------------------
# 3. Retinal Quality & Screening Schemas
# -----------------------------------------------------------------------------
class RetinalQualityResponse(BaseModel):
    quality_grade: str = Field(..., example="GOOD")  # 'GOOD', 'BORDERLINE', 'BAD'
    quality_score: float = Field(..., example=0.88)   # [0.0 - 1.0]
    is_reliable: bool = Field(..., example=True)
    rejection_reasons: List[str] = Field(default_factory=list)
    suspected_clinical_cause: Optional[str] = None
    operator_action: str
    recapture_tips: List[str] = Field(default_factory=list)
    audio_guidance_hindi: str = Field(
        ...,
        example="कैमरा 2 सेमी पास लाएं और मरीज को हरी बत्ती पर देखने को कहें।"
    )
    metrics: Dict[str, Any] = Field(default_factory=dict)


class RetinalAnalysisResponse(BaseModel):
    screening_id: str = Field(..., example="SCR-90123-01")
    patient_id: str = Field(..., example="PT-2026-101")
    eye_side: str = Field(..., example="Right")  # 'Right' or 'Left'
    camera_profile: str = Field(..., example="Generic Fundus Camera")

    # Quality Gate Outcome
    quality_grade: str = Field(..., example="GOOD")
    quality_score: float = Field(..., example=0.88)
    quality_passed: bool = Field(..., example=True)
    rejection_reasons: List[str] = Field(default_factory=list)
    suspected_clinical_cause: Optional[str] = None

    # Model 2 DR Prediction (Suppressed if quality failed)
    dr_grade: Optional[int] = Field(None, example=2)  # 0 to 4
    dr_label: Optional[str] = Field(None, example="Moderate NPDR")
    prediction_score: Optional[float] = Field(None, example=0.742)  # Model top-1 score
    probabilities: Optional[List[float]] = None
    is_referable: Optional[bool] = Field(None, example=True)

    # Uncertainty & Human Review Routing
    requires_human_review: bool = Field(..., example=True)
    human_review_type: str = Field(..., example="CLINICAL_LEVEL")  # 'NONE', 'OPERATOR_LEVEL', 'CLINICAL_LEVEL'
    human_review_reason: Optional[str] = Field(None, example="Referable DR Grade 2 detected")
    confidence_flags: List[str] = Field(default_factory=list)

    # Explainability
    original_image_url: Optional[str] = None
    gradcam_overlay_url: Optional[str] = None
    gradcam_target_layer: Optional[str] = Field(None, example="final_convolutional_block")
    gradcam_disclaimer: str = (
        "Grad-CAM visualizes regions of highest gradient activation influencing the "
        "model prediction. It does not constitute automated lesion segmentation."
    )

    # Clinical Actions & Plain Patient Language
    action_recommendation: str = Field(..., example="Refer for comprehensive ophthalmic examination within 30 days.")
    patient_plain_language_summary: str = Field(
        ...,
        example="Signs of mild-to-moderate changes in blood vessels detected. An eye doctor review has been scheduled."
    )
    created_at: str


# -----------------------------------------------------------------------------
# 4. Doctor Review Queue & Decision Schemas
# -----------------------------------------------------------------------------
class DoctorReviewItem(BaseModel):
    review_id: str
    screening_id: str
    patient_id: str
    patient_name: str
    patient_age: int
    patient_gender: str
    village: Optional[str]
    eye_side: str
    quality_grade: str
    dr_grade_num: Optional[int]
    dr_grade_label: Optional[str]
    dr_confidence: Optional[float]
    is_referable: bool
    requires_human_review: bool
    human_review_type: str
    human_review_reason: Optional[str]
    original_image_url: Optional[str]
    gradcam_overlay_url: Optional[str]
    status: str = "PENDING"  # 'PENDING', 'CONFIRMED', 'OVERRIDDEN', 'REFERRED', 'RECAPTURE_REQUESTED'
    doctor_name: Optional[str] = None
    doctor_decision: Optional[str] = None
    clinical_notes: Optional[str] = None
    referral_urgency: Optional[str] = None
    follow_up_days: Optional[int] = None
    created_at: str
    reviewed_at: Optional[str] = None


class DoctorReviewListResponse(BaseModel):
    total_pending: int
    items: List[DoctorReviewItem]


class DoctorDecisionRequest(BaseModel):
    doctor_name: str = Field(..., example="Dr. S. Ramanathan, MD (Ophthal)")
    decision: str = Field(..., example="CONFIRM_AND_REFER")  # 'CONFIRM', 'OVERRIDE_GRADE', 'REQUEST_RECAPTURE', 'ROUTINE_FOLLOW_UP'
    grade_override: Optional[int] = Field(None, ge=0, le=4, example=2)
    clinical_notes: str = Field(..., example="Multiple microaneurysms confirmed in macular region. Refer to District Eye Hospital.")
    referral_urgency: str = Field("Within 30 Days", example="Within 30 Days")  # 'Immediate', 'Within 30 Days', 'Routine 12 Months'
    follow_up_days: int = Field(30, example=30)


class DoctorDecisionResponse(BaseModel):
    success: bool
    message: str
    review_id: str
    updated_status: str


# -----------------------------------------------------------------------------
# 5. Offline Synchronization Schemas
# -----------------------------------------------------------------------------
class OfflineSyncItem(BaseModel):
    local_screening_id: str
    patient_id: str
    eye_side: str
    image_base64: str
    camera_profile: Optional[str] = "Generic Fundus Camera"
    timestamp: str


class OfflineSyncBatchRequest(BaseModel):
    screening_centre: str
    operator_name: str
    screenings: List[OfflineSyncItem]


class OfflineSyncBatchResponse(BaseModel):
    total_received: int
    total_synced: int
    failed_items: List[Dict[str, str]]
    synced_screening_ids: List[str]


# -----------------------------------------------------------------------------
# 6. System Status Schemas
# -----------------------------------------------------------------------------
class SystemStatusResponse(BaseModel):
    ai_engine: str = "Ready (Model 1 Quality + Model 2 DR + Grad-CAM++)"
    camera_input: str = "Ready (Generic Fundus Camera / JPG / PNG)"
    network_connectivity: str = "Online"
    pending_doctor_reviews: int = 0
    total_patients_registered: int = 0
    total_screenings_completed: int = 0
    offline_queue_ready: bool = True
    models_loaded: Dict[str, str]
    last_sync_time: str
