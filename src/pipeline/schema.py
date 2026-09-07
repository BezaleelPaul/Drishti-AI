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
    SEVERE_BLUR = "Severe blur / loss of retinal focus"
    INADEQUATE_ILLUMINATION = "Inadequate illumination / underexposure"
    OVEREXPOSURE = "Severe glare / overexposure"
    LOW_CONTRAST = "Low vessel-background contrast"
    INSUFFICIENT_FIELD_OF_VIEW = "Insufficient retinal field of view / off-center"
    NON_FUNDUS_OR_CORRUPT = "Non-fundus or corrupt image file"
    BORDERLINE_MARGINAL = "Marginal quality across focus or illumination"


@dataclass
class QualityMetrics:
    sharpness_score: float = 0.0          # Laplacian variance / frequency content
    mean_brightness: float = 0.0          # Average pixel luminance [0, 255]
    contrast_score: float = 0.0           # Standard deviation / dynamic range
    fov_ratio: float = 0.0                # Detected retinal circle area ratio
    raw_scores: Dict[str, float] = field(default_factory=dict)


@dataclass
class QualityAssessmentResult:
    grade: QualityGrade
    is_reliable: bool
    reasons: List[QualityReason] = field(default_factory=list)
    metrics: QualityMetrics = field(default_factory=QualityMetrics)
    details: str = ""


@dataclass
class DRClassificationResult:
    predicted_grade: DRGrade
    probabilities: List[float]            # 5-class probability vector [P0, P1, P2, P3, P4]
    confidence: float                     # Top-1 softmax probability
    top2_margin: float                    # Top-1 minus Top-2 probability
    is_referable: bool                    # Grade >= 2


@dataclass
class ConfidenceAssessment:
    is_confident: bool
    is_ambiguous: bool
    is_high_risk: bool
    requires_human_review: bool
    flags: List[str] = field(default_factory=list)


@dataclass
class GradCAMResult:
    heatmap_generated: bool
    heatmap_array: Optional[Any] = None   # uint8 RGB overlay or normalized heatmap array
    overlay_path: Optional[str] = None
    target_layer: str = "final_conv_layer"
    disclaimer: str = (
        "Grad-CAM indicates regions most influential to the model prediction. "
        "It does not prove the presence of specific lesions and is not lesion segmentation."
    )


class HumanReviewType(str, Enum):
    NONE = "NONE"
    OPERATOR_LEVEL = "OPERATOR_LEVEL"   # Ungradable / recapture issues (trained field operator)
    CLINICAL_LEVEL = "CLINICAL_LEVEL"   # Ambiguous / high-risk DR grades (ophthalmologist/tele-review)


@dataclass
class ScreeningRecord:
    """
    Standard screening record matching Section 25 of the Approved Specification.
    Strict non-negotiable rule: A Bad or still-unreliable image must NEVER carry
    a DR grade in its report, even a low-confidence one.
    """
    image_path: str
    quality_grade: QualityGrade
    quality_status: str                   # 'Reliable', 'Unreliable', 'Reassessment Pending'
    rejection_reasons: List[str] = field(default_factory=list)
    recapture_attempt_count: int = 0
    reassessment_outcome: ReassessmentOutcome = ReassessmentOutcome.NOT_APPLICABLE
    
    # Model 2 fields (Only populated if quality cleared to Reliable Original Image)
    dr_prediction: Optional[DRClassificationResult] = None
    confidence_assessment: Optional[ConfidenceAssessment] = None
    gradcam_result: Optional[GradCAMResult] = None
    
    # Routing & Terminal safety
    human_review_required: bool = False
    human_review_type: HumanReviewType = HumanReviewType.NONE
    human_review_reason: Optional[str] = None
    action: str = ""

    def format_report_text(self) -> str:
        """Formats the official screening report per Section 25."""
        if not self.quality_grade == QualityGrade.GOOD and self.dr_prediction is None:
            reasons_str = " / ".join(self.rejection_reasons) if self.rejection_reasons else "Image quality verification failed"
            return (
                f"Image Quality:    {self.quality_grade.value}\n"
                f"Reason:           {reasons_str}\n"
                f"DR Prediction:    Not generated\n"
                f"Action:           {self.action}"
            )
        else:
            grade_str = f"Grade {self.dr_prediction.predicted_grade.value} — {self.dr_prediction.predicted_grade.label}"
            conf_pct = f"{self.dr_prediction.confidence * 100:.1f}%"
            gradcam_str = "Grad-CAM generated" if (self.gradcam_result and self.gradcam_result.heatmap_generated) else "Not generated"
            
            report = (
                f"Image Quality:    GOOD\n"
                f"Quality Status:   {self.quality_status}\n"
                f"DR Prediction:    {grade_str}\n"
                f"Confidence:       {conf_pct}\n"
                f"Explainability:   {gradcam_str}\n"
                f"Action:           {self.action}"
            )
            if self.human_review_required:
                report += f"\nHuman Review:     FLAGGED ({self.human_review_type.value}: {self.human_review_reason})"
            return report
