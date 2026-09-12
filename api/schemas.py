"""
Pydantic Schemas for Netra-AI FastAPI REST API.
Complies with clinical guidelines, plain-language patient summaries,
and ABDM tele-ophthalmology requirements.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


# -----------------------------------------------------------------------------
# 1. Patient Schemas
# -----------------------------------------------------------------------------
class PatientBase(BaseModel):
    name: str = Field(..., max_length=120, json_schema_extra={"example": "Ramesh Kumar"})
    age: int = Field(..., ge=1, le=120, json_schema_extra={"example": 54})
    gender: str = Field(..., max_length=32, json_schema_extra={"example": "Male"})
    phone: Optional[str] = Field(None, max_length=32, json_schema_extra={"example": "+91 98451 22340"})
    abha_id: Optional[str] = Field(None, max_length=32, json_schema_extra={"example": "91-4521-8890-3321"})
    village: Optional[str] = Field(None, max_length=120, json_schema_extra={"example": "Shivaji Nagar, PHC Bhor"})
    screening_centre: Optional[str] = Field(None, max_length=120, json_schema_extra={"example": "Bhor Rural Health Sub-Centre"})

    # Diabetes Context
    known_diabetes: str = Field("Unknown", max_length=32, json_schema_extra={"example": "Yes"})  # 'Yes', 'No', 'Unknown'
    diabetes_duration_years: Optional[float] = Field(None, ge=0, le=80, json_schema_extra={"example": 6.0})
    hba1c: Optional[float] = Field(None, ge=3, le=20, json_schema_extra={"example": 8.2})
    fasting_glucose: Optional[float] = Field(None, ge=20, le=1000, json_schema_extra={"example": 165.0})
    blood_pressure: Optional[str] = Field(None, max_length=16, json_schema_extra={"example": "138/86"})

    # Upstream Risk Factors
    bmi: Optional[float] = Field(None, ge=10, le=70, json_schema_extra={"example": 28.4})
    family_history: bool = Field(False, json_schema_extra={"example": True})
    physical_activity: str = Field("Moderate", max_length=32, json_schema_extra={"example": "Sedentary"})
    symptoms: List[str] = Field(default_factory=list, max_length=30, json_schema_extra={"example": ["Blurry vision", "Mild fatigue"]})


class PatientCreate(PatientBase):
    patient_id: Optional[str] = Field(None, json_schema_extra={"example": "PT-2026-101"})


class PatientResponse(PatientBase):
    patient_id: str
    created_at: str

    model_config = ConfigDict(from_attributes=True)


class PatientListResponse(BaseModel):
    total: int
    patients: List[PatientResponse]


# -----------------------------------------------------------------------------
# 2. Diabetes Risk Screening Schemas
# -----------------------------------------------------------------------------
class DiabetesRiskRequest(BaseModel):
    patient_id: Optional[str] = None
    age: int = Field(..., ge=0, le=120, json_schema_extra={"example": 54})
    gender: str = Field(..., json_schema_extra={"example": "Male"})
    bmi: float = Field(..., ge=10, le=70, json_schema_extra={"example": 28.4})
    family_history: bool = Field(..., json_schema_extra={"example": True})
    physical_activity: str = Field("Sedentary", json_schema_extra={"example": "Sedentary"})
    symptoms: List[str] = Field(default_factory=list, max_length=30, json_schema_extra={"example": ["Blurry vision"]})
    hba1c: Optional[float] = Field(None, ge=3, le=20, json_schema_extra={"example": 8.2})
    fasting_glucose: Optional[float] = Field(None, ge=20, le=1000, json_schema_extra={"example": 165.0})
    known_diabetes_years: Optional[float] = Field(None, ge=0, le=80, json_schema_extra={"example": 6.0})


class DiabetesRiskResponse(BaseModel):
    risk_score: float = Field(..., json_schema_extra={"example": 84.0})  # 0 to 100
    risk_level: str = Field(..., json_schema_extra={"example": "HIGH"})   # 'LOW', 'MODERATE', 'HIGH'
    pathway: str = Field(..., json_schema_extra={"example": "RETINAL_SCREENING_INDICATED"})
    # 'clinical_rule' for diagnostic biomarkers, 'ml' for model-weighted
    # prediction, and 'heuristic' when the fallback is used.
    # Clients MUST treat 'heuristic' as non-diagnostic and warn the user.
    risk_source: str = Field(..., json_schema_extra={"example": "ml"})
    clinical_rationale: List[str] = Field(default_factory=list)
    action_recommendation: str = Field(..., json_schema_extra={"example": "Retinal imaging indicated for Diabetic Retinopathy screening."})
    patient_friendly_guidance: str = Field(
        ...,
        json_schema_extra={"example": "The assessment indicates elevated risk factors. Clinical testing and retinal screening are recommended."}
    )


# -----------------------------------------------------------------------------
# 3. Retinal Quality & Screening Schemas
# -----------------------------------------------------------------------------
class RetinalQualityResponse(BaseModel):
    quality_grade: str = Field(..., json_schema_extra={"example": "GOOD"})  # 'GOOD', 'BORDERLINE', 'BAD'
    quality_score: float = Field(..., json_schema_extra={"example": 0.88})   # [0.0 - 1.0]
    is_reliable: bool = Field(..., json_schema_extra={"example": True})
    rejection_reasons: List[str] = Field(default_factory=list)
    suspected_clinical_cause: Optional[str] = None
    operator_action: str
    recapture_tips: List[str] = Field(default_factory=list)
    audio_guidance_hindi: str = Field(
        ...,
        json_schema_extra={"example": "कैमरा 2 सेमी पास लाएं और मरीज को हरी बत्ती पर देखने को कहें।"}
    )
    metrics: Dict[str, Any] = Field(default_factory=dict)


class RetinalAnalysisResponse(BaseModel):
    screening_id: str = Field(..., json_schema_extra={"example": "SCR-90123-01"})
    patient_id: str = Field(..., json_schema_extra={"example": "PT-2026-101"})
    eye_side: str = Field(..., json_schema_extra={"example": "Right"})  # 'Right' or 'Left'
    camera_profile: str = Field(..., json_schema_extra={"example": "Generic Fundus Camera"})

    # Quality Gate Outcome
    quality_grade: str = Field(..., json_schema_extra={"example": "GOOD"})
    quality_score: float = Field(..., json_schema_extra={"example": 0.88})
    quality_passed: bool = Field(..., json_schema_extra={"example": True})
    rejection_reasons: List[str] = Field(default_factory=list)
    suspected_clinical_cause: Optional[str] = None

    # Model 2 DR Prediction (Suppressed if quality failed)
    dr_grade: Optional[int] = Field(None, json_schema_extra={"example": 2})  # 0 to 4
    dr_label: Optional[str] = Field(None, json_schema_extra={"example": "Moderate NPDR"})
    prediction_score: Optional[float] = Field(None, json_schema_extra={"example": 0.742})  # Model top-1 score
    probabilities: Optional[List[float]] = None
    is_referable: Optional[bool] = Field(None, json_schema_extra={"example": True})
    # Which classifier produced this grade: 'keras' | 'pytorch' | 'simulated' |
    # None (unknown, e.g. history rows written before this field existed).
    # Clients MUST treat 'simulated' as non-diagnostic.
    model_backend: Optional[str] = Field(None, json_schema_extra={"example": "keras"})

    # Segmentation biomarkers (None when ungradable — never estimated)
    vessel_density_pct: Optional[float] = Field(None, json_schema_extra={"example": 14.2})
    microaneurysm_count: Optional[int] = Field(None, json_schema_extra={"example": 12})
    csme_risk: Optional[str] = Field(None, json_schema_extra={"example": "LOW"})
    min_fovea_distance_px: Optional[float] = Field(None, json_schema_extra={"example": 310.0})

    # Uncertainty & Human Review Routing
    requires_human_review: bool = Field(..., json_schema_extra={"example": True})
    human_review_type: str = Field(..., json_schema_extra={"example": "CLINICAL_LEVEL"})  # 'NONE', 'OPERATOR_LEVEL', 'CLINICAL_LEVEL'
    human_review_reason: Optional[str] = Field(None, json_schema_extra={"example": "Referable DR Grade 2 detected"})
    confidence_flags: List[str] = Field(default_factory=list)

    # Explainability
    original_image_url: Optional[str] = None
    gradcam_overlay_url: Optional[str] = None
    gradcam_target_layer: Optional[str] = Field(None, json_schema_extra={"example": "final_convolutional_block"})
    gradcam_disclaimer: str = (
        "Grad-CAM visualizes regions of highest gradient activation influencing the "
        "model prediction. It does not constitute automated lesion segmentation."
    )

    # Clinical Actions & Plain Patient Language
    action_recommendation: str = Field(..., json_schema_extra={"example": "Refer for comprehensive ophthalmic examination within 30 days."})
    patient_plain_language_summary: str = Field(
        ...,
        json_schema_extra={"example": "Signs of mild-to-moderate changes in blood vessels detected. An eye doctor review has been scheduled."}
    )
    created_at: str
    # Field-capture time for offline-synced items (server created_at = sync time).
    captured_at: Optional[str] = Field(None, json_schema_extra={"example": "2026-01-01T00:00:00"})


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
    abha_id: Optional[str] = None
    eye_side: str
    quality_grade: str
    dr_grade_num: Optional[int]
    dr_grade_label: Optional[str]
    dr_confidence: Optional[float]
    # NULL in DB means ungradable (never coerced to False = healthy).
    is_referable: Optional[bool] = None
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
    doctor_name: str = Field(..., max_length=120, json_schema_extra={"example": "Dr. S. Ramanathan, MD (Ophthal)"})
    decision: str = Field(..., json_schema_extra={"example": "CONFIRM_AND_REFER"})  # 'CONFIRM', 'OVERRIDE_GRADE', 'REQUEST_RECAPTURE', 'ROUTINE_FOLLOW_UP'
    grade_override: Optional[int] = Field(None, ge=0, le=4, json_schema_extra={"example": 2})
    clinical_notes: str = Field(..., max_length=2000, json_schema_extra={"example": "Multiple microaneurysms confirmed in macular region. Refer to District Eye Hospital."})
    referral_urgency: str = Field("Within 30 Days", max_length=64, json_schema_extra={"example": "Within 30 Days"})  # 'Immediate', 'Within 30 Days', 'Routine 12 Months'
    follow_up_days: int = Field(30, ge=0, le=365, json_schema_extra={"example": 30})


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
    # Pydantic-level byte cap: the route-level check runs only AFTER the
    # full JSON body is parsed, so without this, 20 max-size items would
    # sit in RAM (~210MB) before rejection. 15M chars ~= 11MB decoded.
    image_base64: str = Field(..., max_length=15_000_000)
    camera_profile: Optional[str] = Field("Generic Fundus Camera", max_length=128)
    timestamp: str


class OfflineSyncBatchRequest(BaseModel):
    screening_centre: str = Field(..., max_length=120)
    operator_name: str = Field(..., max_length=120)
    # Capped at 5: each item costs a full multi-second inference in-request,
    # and the 90s client timeout cannot survive larger batches. The global
    # middleware body cap is sized for this bound (see ratelimit.SYNC cap).
    screenings: List[OfflineSyncItem] = Field(..., max_length=5)


class OfflineSyncBatchResponse(BaseModel):
    total_received: int
    total_synced: int
    failed_items: List[Dict[str, str]]
    # LOCAL screening ids the client queued (its dedup key): the server ids
    # are traceable via synced_items. A previous version returned server ids
    # here, which clients match against local ids — the queue never drained.
    synced_screening_ids: List[str]
    synced_items: List[Dict[str, str]] = Field(default_factory=list)


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
