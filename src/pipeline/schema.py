from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Any


class QualityGrade(str, Enum):
    GOOD = "GOOD"
    BORDERLINE = "BORDERLINE"
    BAD = "BAD"


class ReassessmentOutcome(str, Enum):
    CLEARED = "CLEARED"      # 5-No: joins Good path
    FAILED = "FAILED"        # 5-Yes: sent to Recapture / Human Review
    NOT_APPLICABLE = "N/A"


class DRGrade(int, Enum):
    NO_DR = 0
    MILD_NPDR = 1
    MODERATE_NPDR = 2
    SEVERE_NPDR = 3
    PROLIFERATIVE_DR = 4

    @property
    def label(self) -> str:
        labels = {
            0: "No DR",
            1: "Mild NPDR",
            2: "Moderate NPDR",
            3: "Severe NPDR",
            4: "Proliferative DR",
        }
        return labels[self.value]

    @property
    def is_referable(self) -> bool:
        """Referable DR is defined at grade >= 2."""
        return self.value >= 2

    @property
    def is_high_risk(self) -> bool:
        """High-risk grades (Severe, Proliferative) per Section 7."""
        return self.value in (3, 4)


class QualityReason(str, Enum):
    ADEQUATE = "Adequate diagnostic quality"
    SEVERE_BLUR = "Severe blur / loss of retinal focus (Suspected camera defocus or media opacity/cataract)"
    INADEQUATE_ILLUMINATION = "Inadequate illumination (Suspected insufficient pupil dilation or non-mydriatic issue)"
    OVEREXPOSURE = "Severe glare / overexposure (Corneal reflection or tear film drying)"
    LOW_CONTRAST = "Low vessel-background contrast"
    INSUFFICIENT_FIELD_OF_VIEW = "Insufficient retinal field of view (Patient fixation loss or uncooperative gaze)"
    NON_FUNDUS_OR_CORRUPT = "Non-fundus or corrupt image file"
    BORDERLINE_MARGINAL = "Marginal quality across focus or illumination"
    LOW_ML_QUALITY = "Low ML ensemble quality score (model confidence below cutoff)"


@dataclass
class QualityMetrics:
    sharpness_score: float = 0.0          # Laplacian variance / frequency content
    mean_brightness: float = 0.0          # Average pixel luminance [0, 255]
    contrast_score: float = 0.0           # Standard deviation / dynamic range
    fov_ratio: float = 0.0                # Detected retinal circle area ratio
    raw_scores: Dict[str, Any] = field(default_factory=dict)


@dataclass
class QualityAssessmentResult:
    grade: QualityGrade
    is_reliable: bool
    reasons: List[QualityReason] = field(default_factory=list)
    metrics: QualityMetrics = field(default_factory=QualityMetrics)
    details: str = ""
    suspected_clinical_cause: Optional[str] = None


@dataclass
class DRClassificationResult:
    predicted_grade: DRGrade
    probabilities: List[float]            # 5-class probability vector [P0, P1, P2, P3, P4]
    confidence: float                     # Top-1 softmax probability (uncalibrated)
    top2_margin: float                    # Top-1 minus Top-2 probability
    is_referable: bool                    # Grade >= 2


@dataclass
class ConfidenceAssessment:
    is_confident: bool
    is_ambiguous: bool
    is_high_risk: bool
    requires_human_review: bool
    flags: List[str] = field(default_factory=list)

    def format_confidence_label(self, confidence_val: float, is_referable: bool = False) -> str:
        pct = confidence_val * 100.0
        if not self.is_confident or self.is_ambiguous or self.is_high_risk or is_referable:
            if is_referable and self.is_confident and not self.is_ambiguous:
                return f"{pct:.1f}% — High model confidence but referable grade; human review required"
            return f"{pct:.1f}% — Low confidence; human review recommended"
        return f"{pct:.1f}% — High confidence; meets automated screening threshold"


@dataclass
class GradCAMResult:
    heatmap_generated: bool
    heatmap_array: Optional[Any] = None   # uint8 RGB overlay
    overlay_path: Optional[str] = None
    target_layer: str = "final_conv_layer"
    description: str = "Grad-CAM visualization showing image regions influencing the model prediction."
    disclaimer: str = (
        "Grad-CAM visualization showing image regions influencing the model prediction. "
        "It highlights gradient activation areas for clinician audit and does not prove the "
        "presence of specific lesions (microaneurysms, hemorrhages, or exudates)."
    )


class HumanReviewType(str, Enum):
    NONE = "NONE"
    OPERATOR_LEVEL = "OPERATOR_LEVEL"   # Ungradable / recapture issues (trained field operator)
    CLINICAL_LEVEL = "CLINICAL_LEVEL"   # Ambiguous / high-risk DR grades (ophthalmologist/tele-review)


@dataclass
class ScreeningRecord:
    """
    Standard screening record matching Section 25 with medically calibrated phrasing.
    """
    image_path: str
    quality_grade: QualityGrade
    quality_status: str                   # 'Reliable', 'Unreliable', 'Reassessment Pending'
    rejection_reasons: List[str] = field(default_factory=list)
    recapture_attempt_count: int = 0
    reassessment_outcome: ReassessmentOutcome = ReassessmentOutcome.NOT_APPLICABLE
    suspected_clinical_cause: Optional[str] = None
    
    # Model 2 fields (Only populated if quality cleared to Reliable Original Image)
    dr_prediction: Optional[DRClassificationResult] = None
    confidence_assessment: Optional[ConfidenceAssessment] = None
    gradcam_result: Optional[GradCAMResult] = None
    
    # Routing & Terminal safety
    human_review_required: bool = False
    human_review_type: HumanReviewType = HumanReviewType.NONE
    human_review_reason: Optional[str] = None
    action: str = ""
    quality_metrics: Optional[QualityMetrics] = None
    # Internal reuse: reassessment segmentation result (BORDERLINE-CLEARED
    # path only). Lets biomarker extraction skip a second full segmentation
    # over the same pixels. Never rendered; excluded from reports/exports.
    reassessment_structures: Optional[Any] = None

    # Traceability: which model backend produced the DR grade, and how long
    # the pipeline took. model_backend follows the DRClassifier backend
    # ('keras' | 'pytorch' | 'simulated'). None when unset (legacy or
    # ungradable rows).
    model_backend: Optional[str] = None
    inference_time_ms: Optional[float] = None

    def format_report_text(self) -> str:
        """Formats the official screening report per Section 25."""
        if self.quality_grade != QualityGrade.GOOD or self.dr_prediction is None:
            # CLEARED borderline carries a valid prediction and must show detailed report.
            if not (self.reassessment_outcome == ReassessmentOutcome.CLEARED and self.dr_prediction is not None):
                reasons_str = " / ".join(self.rejection_reasons) if self.rejection_reasons else "Image quality verification failed"
                cause_str = f"\nSuspected Cause:  {self.suspected_clinical_cause}" if self.suspected_clinical_cause else ""
                return (
                    f"Image Quality:    {self.quality_grade.value}\n"
                    f"Reason:           {reasons_str}{cause_str}\n"
                    f"DR Prediction:    Not generated\n"
                    f"Action:           {self.action}"
                )
        if self.dr_prediction is None:
            reasons_str = " / ".join(self.rejection_reasons) if self.rejection_reasons else "Image quality verification failed"
            cause_str = f"\nSuspected Cause:  {self.suspected_clinical_cause}" if self.suspected_clinical_cause else ""
            return (
                f"Image Quality:    {self.quality_grade.value}\n"
                f"Reason:           {reasons_str}{cause_str}\n"
                f"DR Prediction:    Not generated\n"
                f"Action:           {self.action}"
            )
        else:
            grade_str = f"Grade {self.dr_prediction.predicted_grade.value} — {self.dr_prediction.predicted_grade.label}"
            if self.confidence_assessment:
                conf_display = self.confidence_assessment.format_confidence_label(
                    self.dr_prediction.confidence,
                    is_referable=bool(self.dr_prediction.predicted_grade.is_referable),
                )
            else:
                conf_display = f"{self.dr_prediction.confidence * 100:.1f}%"
                
            gradcam_str = (
                "Grad-CAM visualization showing image regions influencing the model prediction"
                if (self.gradcam_result and self.gradcam_result.heatmap_generated)
                else "Not generated"
            )
            
            report = (
                f"Image Quality:    {self.quality_grade.value}\n"
                f"Quality Status:   {self.quality_status}\n"
                f"DR Prediction:    {grade_str}\n"
                f"Model Confidence: {conf_display}\n"
                f"Explainability:   {gradcam_str}\n"
                f"Action:           {self.action}"
            )
            if self.human_review_required:
                reason_str = self.human_review_reason if self.human_review_reason else "unspecified"
                report += f"\nHuman Review:     FLAGGED ({self.human_review_type.value}: {reason_str})"
            return report
