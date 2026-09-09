from __future__ import annotations

import os
from typing import Optional, Union
import numpy as np
from PIL import Image

from src.quality.checker import ImageQualityChecker
from src.classification.classifier import DRClassifier
from src.classification.gradcam import GradCAMExplainer
from src.pipeline.confidence import ConfidenceEvaluator
from src.pipeline.schema import (
    DRGrade,
    HumanReviewType,
    QualityGrade,
    ReassessmentOutcome,
    ScreeningRecord,
)


class ScreeningPipelineRouter:
    """
    Orchestrates the two-model AI-Assisted DR Screening Pipeline.
    Strictly locked to the approved flowchart (Section 3 and Section 5).
    Enforces the Non-Destructive Processing Rule (Section 20).
    """

    MAX_RECAPTURE_CAP = 2  # Hard cap of 2 recapture attempts per patient per session (Section 5/7)

    def __init__(
        self,
        quality_checker: Optional[ImageQualityChecker] = None,
        dr_classifier: Optional[DRClassifier] = None,
        gradcam_explainer: Optional[GradCAMExplainer] = None,
        confidence_evaluator: Optional[ConfidenceEvaluator] = None,
    ):
        self.quality_checker = quality_checker or ImageQualityChecker()
        self.dr_classifier = dr_classifier or DRClassifier()
        self.gradcam_explainer = gradcam_explainer or GradCAMExplainer(classifier_backend=self.dr_classifier)
        self.confidence_evaluator = confidence_evaluator or ConfidenceEvaluator()

    def process_image(
        self,
        image_input: Union[str, np.ndarray, Image.Image],
        recapture_attempt_count: int = 0,
        output_dir: Optional[str] = None,
    ) -> ScreeningRecord:
        """
        Executes Node 1 to Node 11 of the approved decision flow.

        Args:
            image_input: File path, numpy array, or PIL Image.
            recapture_attempt_count: Number of previous recapture attempts for this patient session.
            output_dir: Directory to save generated Grad-CAM overlays or reports.
        """
        image_path = image_input if isinstance(image_input, str) else "in_memory_capture.jpg"

        # -------------------------------------------------------------
        # Node 1: FUNDUS IMAGE (Raw retinal photograph enters the system)
        # -------------------------------------------------------------
        
        # -------------------------------------------------------------
        # Node 2: IMAGE QUALITY CHECK (Model 1 runs)
        # -------------------------------------------------------------
        quality_res = self.quality_checker.assess_image(image_input, strict_mode=False)

        # -------------------------------------------------------------
        # Node 3c: BAD IMAGE PATH
        # -------------------------------------------------------------
        if quality_res.grade == QualityGrade.BAD:
            reasons_list = [r.value for r in quality_res.reasons]

            # Check if retry limit reached (Section 5 / Section 18)
            if recapture_attempt_count >= self.MAX_RECAPTURE_CAP:
                # Force-escalate to human review
                return ScreeningRecord(
                    image_path=image_path,
                    quality_grade=QualityGrade.BAD,
                    quality_status="Unreliable (Retry limit reached)",
                    rejection_reasons=reasons_list,
                    recapture_attempt_count=recapture_attempt_count,
                    reassessment_outcome=ReassessmentOutcome.NOT_APPLICABLE,
                    suspected_clinical_cause=quality_res.suspected_clinical_cause,
                    dr_prediction=None,
                    confidence_assessment=None,
                    gradcam_result=None,
                    human_review_required=True,
                    human_review_type=HumanReviewType.OPERATOR_LEVEL,
                    human_review_reason=(
                        f"Recapture cap of {self.MAX_RECAPTURE_CAP} attempts reached. "
                        f"Operator/clinician must inspect patient eye directly."
                    ),
                    action=(
                        f"Recapture cap reached ({recapture_attempt_count}/{self.MAX_RECAPTURE_CAP}). "
                        f"Escalate to supervising clinician for on-site physical evaluation."
                    ),
                    quality_metrics=quality_res.metrics,
                )

            # Standard Bad: prompt for immediate recapture
            return ScreeningRecord(
                image_path=image_path,
                quality_grade=QualityGrade.BAD,
                quality_status="Unreliable",
                rejection_reasons=reasons_list,
                recapture_attempt_count=recapture_attempt_count + 1,
                reassessment_outcome=ReassessmentOutcome.NOT_APPLICABLE,
                suspected_clinical_cause=quality_res.suspected_clinical_cause,
                dr_prediction=None,
                confidence_assessment=None,
                gradcam_result=None,
                human_review_required=False,
                human_review_type=HumanReviewType.NONE,
                action=(
                    "Recapture image. Do not display a DR grade for an image "
                    "that fails the reliability gate."
                ),
                quality_metrics=quality_res.metrics,
            )

        # -------------------------------------------------------------
        # Node 3b: BORDERLINE IMAGE PATH -> Node 4: REASSESSMENT
        # -------------------------------------------------------------
        reassessment_outcome = ReassessmentOutcome.NOT_APPLICABLE
        if quality_res.grade == QualityGrade.BORDERLINE:
            # Reassessment: Re-evaluate frame with stricter decision thresholds (Section 5)
            strict_res = self.quality_checker.assess_image(image_input, strict_mode=True)

            # Node 5: STILL UNRELIABLE?
            if strict_res.grade == QualityGrade.GOOD:
                # 5-No: joins Good path
                reassessment_outcome = ReassessmentOutcome.CLEARED
            else:
                # 5-Yes: Reassessment failed -> Recapture / Human Review
                reassessment_outcome = ReassessmentOutcome.FAILED
                reasons = [r.value for r in quality_res.reasons]
                return ScreeningRecord(
                    image_path=image_path,
                    quality_grade=QualityGrade.BORDERLINE,
                    quality_status="Unreliable (Failed Reassessment)",
                    rejection_reasons=reasons,
                    recapture_attempt_count=recapture_attempt_count + 1,
                    reassessment_outcome=reassessment_outcome,
                    suspected_clinical_cause=quality_res.suspected_clinical_cause,
                    dr_prediction=None,
                    confidence_assessment=None,
                    gradcam_result=None,
                    human_review_required=True,
                    human_review_type=HumanReviewType.OPERATOR_LEVEL,
                    human_review_reason="Borderline image failed strict reassessment verification.",
                    action=(
                        "Reassessment failed. Request fresh capture or flag for field operator "
                        "inspection. Image does NOT proceed to DR Classification."
                    ),
                    quality_metrics=quality_res.metrics,
                )

        # -------------------------------------------------------------
        # Node 6: RELIABLE ORIGINAL IMAGE
        # Convergence point for 3a (Good) and 5-No (Cleared Borderline).
        # Holds original, unmodified pixel data (Section 20).
        # -------------------------------------------------------------
        quality_status = "Reliable" if reassessment_outcome != ReassessmentOutcome.CLEARED else "Reliable (Cleared by Reassessment)"

        # -------------------------------------------------------------
        # Node 7: DR CLASSIFICATION (Model 2 runs)
        # -------------------------------------------------------------
        dr_result = self.dr_classifier.predict(image_input)

        # -------------------------------------------------------------
        # Node 8: CONFIDENCE / UNCERTAINTY HANDLING
        # -------------------------------------------------------------
        confidence_result = self.confidence_evaluator.evaluate(dr_result)

        # -------------------------------------------------------------
        # Node 9: GRAD-CAM EXPLAINABILITY
        # Generated for all images reaching this node per Section 8
        # -------------------------------------------------------------
        overlay_save_path = None
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
            overlay_save_path = os.path.join(output_dir, "gradcam_overlay.png")

        gradcam_res = self.gradcam_explainer.generate_heatmap(
            image_input=image_input,
            target_grade=dr_result.predicted_grade,
            save_path=overlay_save_path,
            classifier=self.dr_classifier,
        )

        # -------------------------------------------------------------
        # Node 10 & 11: SCREENING RESULT & HUMAN REVIEW ROUTING
        # -------------------------------------------------------------
        human_review_req = confidence_result.requires_human_review
        review_type = HumanReviewType.CLINICAL_LEVEL if human_review_req else HumanReviewType.NONE
        review_reason = " | ".join(confidence_result.flags) if human_review_req else None

        if dr_result.predicted_grade.value == 0:
            if human_review_req:
                action_text = "Routine annual screening recommended. Low confidence / ambiguity flagged for clinical verification."
            else:
                action_text = "Routine screening: No DR detected. Rescreen in 12 months."
        elif dr_result.predicted_grade.value == 1:
            if human_review_req:
                action_text = "Mild NPDR flagged for clinician over-read. Follow-up per clinical guidelines."
            else:
                action_text = "Mild NPDR detected. Routine 6-12 month follow-up recommended."
        else:
            action_text = "Refer for ophthalmic evaluation / human review per workflow."

        return ScreeningRecord(
            image_path=image_path,
            quality_grade=QualityGrade.GOOD,
            quality_status=quality_status,
            rejection_reasons=[],
            recapture_attempt_count=recapture_attempt_count,
            reassessment_outcome=reassessment_outcome,
            suspected_clinical_cause=None,
            dr_prediction=dr_result,
            confidence_assessment=confidence_result,
            gradcam_result=gradcam_res,
            human_review_required=human_review_req,
            human_review_type=review_type,
            human_review_reason=review_reason,
            action=action_text,
            quality_metrics=quality_res.metrics,
        )
