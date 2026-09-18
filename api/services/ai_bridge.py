"""
AI Bridge Service.
Binds FastAPI HTTP requests directly to the validated Python AI models:
- Model 1: ImageQualityChecker (FIT ensemble / multi-scale fusion)
- Model 2: DRClassifier (EfficientNetB0 5-class severity)
- Explainability: GradCAMExplainer (Grad-CAM++ higher-order gradients)
- Upstream Risk: DiabetesRiskModel (Random Forest risk engine)
"""
from __future__ import annotations

import io
import logging
import os
import shutil
import threading
import time
import uuid
from datetime import datetime, timezone
from typing import Any

import numpy as np
from PIL import Image

from src.classification.classifier import ClinicalModelUnavailableError, DRClassifier
from src.classification.gradcam import GradCAMExplainer
from src.clinical_risk import (
    DiabetesRiskModel,
    PatientClinicalProfile,
)
from src.pipeline.router import ScreeningPipelineRouter
from src.pipeline.schema import QualityGrade, ScreeningRecord
from src.quality.checker import ImageQualityChecker, QualityThresholds
from src.quality.enhancer import AdaptiveQualityEnhancer

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_RESULTS_DIR = os.path.join(_PROJECT_ROOT, "results", "api_screenings")
os.makedirs(_RESULTS_DIR, exist_ok=True)

_logger = logging.getLogger("NetraAI.AIBridge")


def _confidence_flags_with_ood(base_flags, probs) -> list:
    """Copies router confidence flags and appends an advisory OOD flag.

    Never raises, never blocks grading: any OOD failure degrades to the
    router flags alone.
    """
    flags = list(base_flags) if base_flags else []
    try:
        if probs:
            from src.quality.ood import ood_score
            res = ood_score(probs)
            if res.is_suspect:
                flags.append(f"OOD_SUSPECT (score {res.ood_score:.2f}): " + "; ".join(res.signals))
    except Exception as exc:  # noqa: BLE001 - OOD is advisory and must not block grading
        _logger.debug("OOD check failed: %s", exc)
    return flags


class AIBridge:
    """Singleton bridge encapsulating loaded models and orchestrating inference."""

    _instance: AIBridge | None = None
    _lock = threading.Lock()

    def __init__(self):
        self.risk_model = DiabetesRiskModel()
        self.quality_checker = ImageQualityChecker()
        self.quality_enhancer = AdaptiveQualityEnhancer()
        self.dr_classifier = DRClassifier()
        self.gradcam_explainer = GradCAMExplainer(
            classifier_backend=self.dr_classifier,
            use_gradcam_plus_plus=True,
        )
        self.router = ScreeningPipelineRouter(
            quality_checker=self.quality_checker,
            dr_classifier=self.dr_classifier,
            gradcam_explainer=self.gradcam_explainer,
        )

    @classmethod
    def get_instance(cls) -> AIBridge:
        if cls._instance is None:
            # Double-checked locking on a SHARED class-level lock. (A lock
            # created per call would give each thread its own lock and no
            # mutual exclusion at all.)
            with cls._lock:
                if cls._instance is None:
                    cls._instance = AIBridge()
        return cls._instance

    # Hard ceiling on decoded pixels: a <=10MB high-compression PNG can
    # otherwise expand to gigapixels and OOM the worker at np.array().
    _MAX_IMAGE_PIXELS = 50_000_000

    @staticmethod
    def _open_image_capped(image_bytes: bytes):
        """Decode with an early dimension check (before convert/np.array).
        PIL opens lazily, so .size reads only the header — a gigapixel
        high-compression PNG is rejected before any pixel buffer exists."""
        from PIL import Image as _PILImage
        from PIL import UnidentifiedImageError
        if not image_bytes or len(image_bytes) > 10 * 1024 * 1024:
            raise ValueError("Image too large or empty (max 10MB)")
        try:
            pil_img = _PILImage.open(io.BytesIO(image_bytes))
            w, h = pil_img.size
            if w <= 0 or h <= 0 or w * h > AIBridge._MAX_IMAGE_PIXELS:
                raise ValueError(
                    f"Image dimensions {w}x{h} outside decodable range "
                    f"(max {AIBridge._MAX_IMAGE_PIXELS} pixels).")
            return pil_img.convert("RGB")
        except (UnidentifiedImageError, OSError) as e:
            raise ValueError(f"Invalid image file: {e}")

    # -------------------------------------------------------------------------
    # 1. Image Quality Fast-Check (Standalone)
    # -------------------------------------------------------------------------
    def assess_quality(self, image_bytes: bytes, camera_profile: str = "Generic") -> dict[str, Any]:
        pil_img = self._open_image_capped(image_bytes)
        np_img = np.array(pil_img)

        # Select camera threshold if specified (case-insensitive)
        cp = (camera_profile or "").lower()
        if "forus" in cp:
            th = QualityThresholds.for_forus_3nethra()
            checker = ImageQualityChecker(thresholds=th)
        elif "remidio" in cp:
            th = QualityThresholds.for_remidio_fop()
            checker = ImageQualityChecker(thresholds=th)
        elif "volk" in cp:
            th = QualityThresholds.for_volk_inview()
            checker = ImageQualityChecker(thresholds=th)
        else:
            checker = self.quality_checker

        result = checker.assess_image(np_img)
        ml_score = float(result.metrics.raw_scores.get("ml_quality_score", 0.0))

        # Build clear ASHA / rural operator instructions
        reasons_str = [r.value for r in result.reasons]
        tips = []
        hindi_guide = "कैमरा स्थिर रखें और मरीज को केंद्र में देखने को कहें।"

        if result.grade == QualityGrade.BAD or result.grade == QualityGrade.BORDERLINE:
            for r in result.reasons:
                if "blur" in r.value.lower():
                    tips.append("Adjust camera diopter dial (+/- 2D) or stabilize against patient brow.")
                    hindi_guide = "कृपया कैमरा 2 सेमी पास लाएं और फोकस डायल घुमाएं।"
                elif "illumination" in r.value.lower() or "dark" in r.value.lower():
                    tips.append("Dim room lights for 3 minutes for natural physiological dilation.")
                    hindi_guide = "कमरे की लाइट धीमी करें ताकि पुतली स्वाभाविक रूप से फैल सके।"
                elif "glare" in r.value.lower() or "overexposure" in r.value.lower():
                    tips.append("Reposition slightly to eliminate corneal glare.")
                    hindi_guide = "कैमरे का कोण थोड़ा बदलें ताकि चमक कम हो सके।"
                elif "ml ensemble" in r.value.lower() or "ml quality" in r.value.lower():
                    tips.append("AI quality check is uncertain — clean lens, re-center, and recapture in stable light.")
                    hindi_guide = "लेंस साफ करें, आंख को केंद्र में रखें और दोबारा फोटो लें।"
                elif "contrast" in r.value.lower():
                    tips.append("Low vessel contrast — dim room lights and recapture with steady fixation.")
                    hindi_guide = "कमरे की लाइट धीमी करें और दोबारा फोटो लें।"
                elif "field" in r.value.lower():
                    tips.append("Ask patient to fixate steadily on the internal green fixation target.")
                    hindi_guide = "मरीज को कैमरे के अंदर हरी बत्ती पर स्थिर देखने को कहें।"

        if not tips and result.grade != QualityGrade.GOOD:
            tips.append("Ensure pupil is aligned and retake capture.")

        return {
            "quality_grade": result.grade.value,
            "quality_score": round(ml_score, 4),
            "is_reliable": result.is_reliable,
            "rejection_reasons": reasons_str,
            "suspected_clinical_cause": result.suspected_clinical_cause,
            "operator_action": "Proceed to DR Analysis" if result.is_reliable else "Please recapture image",
            "recapture_tips": tips,
            "audio_guidance_hindi": hindi_guide,
            "metrics": {
                "sharpness": round(result.metrics.sharpness_score, 1),
                "brightness": round(result.metrics.mean_brightness, 1),
                "contrast": round(result.metrics.contrast_score, 1),
                "fov_ratio": round(result.metrics.fov_ratio, 3),
                "ml_quality_score": round(ml_score, 3),
                "quality_engine": result.metrics.raw_scores.get("quality_engine", "MultiScale_Fusion"),
            },
        }

    # -------------------------------------------------------------------------
    # 2. End-to-End Retinal Screening Analysis
    # -------------------------------------------------------------------------
    def analyze_retina(
        self,
        image_bytes: bytes,
        patient_id: str,
        eye_side: str = "Right",
        camera_profile: str = "Generic Fundus Camera",
    ) -> dict[str, Any]:
        if self.dr_classifier.get_backend() == "simulated":
            raise ClinicalModelUnavailableError(
                "Clinical DR model weights are unavailable; screening was not graded."
            )

        pil_img = self._open_image_capped(image_bytes)
        screening_id = f"SCR-{uuid.uuid4().hex[:12].upper()}"
        screening_dir = os.path.join(_RESULTS_DIR, screening_id)
        os.makedirs(screening_dir, exist_ok=True)

        orig_filename = f"{screening_id}_orig.jpg"
        orig_path = os.path.join(screening_dir, orig_filename)
        try:
            pil_img.save(orig_path, quality=95)
        except Exception:
            shutil.rmtree(screening_dir, ignore_errors=True)
            raise

        # Run pipeline router. output_dir=None: the router would otherwise write
        # a second Grad-CAM PNG (gradcam_<uuid>.png) that nothing references —
        # the single served overlay is saved below from heatmap_array.
        _t0 = time.perf_counter()
        try:
            record: ScreeningRecord = self.router.process_image(
                image_input=orig_path,
                recapture_attempt_count=0,
                output_dir=None,
            )
        except Exception:
            shutil.rmtree(screening_dir, ignore_errors=True)
            raise
        inference_time_ms = round((time.perf_counter() - _t0) * 1000.0, 1)

        # URLs relative to static server
        orig_url = f"/results/{screening_id}/{orig_filename}"
        gradcam_url = None
        target_layer = None

        if record.gradcam_result and record.gradcam_result.heatmap_generated:
            gradcam_filename = f"{screening_id}_gradcam.png"
            gradcam_path = os.path.join(screening_dir, gradcam_filename)
            try:
                Image.fromarray(record.gradcam_result.heatmap_array).save(gradcam_path)
            except Exception:
                shutil.rmtree(screening_dir, ignore_errors=True)
                raise
            gradcam_url = f"/results/{screening_id}/{gradcam_filename}"
            target_layer = record.gradcam_result.target_layer

        # Extract values
        quality_score = 0.0
        if record.quality_metrics and "ml_quality_score" in record.quality_metrics.raw_scores:
            quality_score = float(record.quality_metrics.raw_scores["ml_quality_score"])

        dr_grade = None
        dr_label = None
        conf = None
        probs = None
        is_ref = None

        if record.dr_prediction:
            dr_grade = record.dr_prediction.predicted_grade.value
            dr_label = record.dr_prediction.predicted_grade.label
            conf = float(record.dr_prediction.confidence)
            probs = [round(float(p), 4) for p in record.dr_prediction.probabilities]
            is_ref = record.dr_prediction.is_referable if record.dr_prediction else None

        # Plain language patient explanation
        plain_summary = self._generate_plain_patient_summary(record.quality_grade, dr_grade, is_ref)

        # Real segmentation biomarkers (None when ungradable or on failure — never fabricated)
        # A BORDERLINE capture cleared by reassessment joins the Good path
        # (router: reassessment_outcome==CLEARED with a DR prediction), so it
        # gets segmented and marked passed exactly like GOOD.
        from src.pipeline.schema import ReassessmentOutcome
        _cleared = (
            record.quality_grade == QualityGrade.BORDERLINE
            and getattr(record, "reassessment_outcome", None) == ReassessmentOutcome.CLEARED
        )
        _gradable = (
            record.quality_grade == QualityGrade.GOOD or _cleared
        ) and record.dr_prediction is not None
        vessel_density_pct = None
        microaneurysm_count = None
        csme_risk = None
        min_fovea_distance_px = None
        if _gradable:
            try:
                import numpy as _np
                # Reuse the router's reassessment segmentation on the
                # BORDERLINE-CLEARED path instead of segmenting twice.
                seg = getattr(record, "reassessment_structures", None)
                if seg is None:
                    # Segment the served JPEG bytes (what the router graded),
                    # not the pre-encode upload pixels: JPEG q95 shifts values
                    # slightly and biomarkers must describe the graded image.
                    from PIL import Image as _PILImage
                    try:
                        _served = _PILImage.open(orig_path).convert("RGB")
                        seg = self.router.structure_segmenter.segment_structures(_np.array(_served))
                    except Exception as exc:  # noqa: BLE001 - retry segmentation on upload pixels
                        _logger.debug("Served-image segmentation failed: %s", exc)
                        seg = self.router.structure_segmenter.segment_structures(_np.array(pil_img))
                vessel_density_pct = round(float(seg.vessel_density_pct), 1)
                microaneurysm_count = len(seg.microaneurysm_candidates)
                csme_risk = seg.csme_risk
                if seg.min_fovea_distance_px is not None:
                    min_fovea_distance_px = round(float(seg.min_fovea_distance_px), 1)
            except Exception as exc:  # noqa: BLE001 - biomarkers are advisory, never block screening
                _logger.warning("Biomarker extraction failed for %s: %s", screening_id, exc)

        return {
            "screening_id": screening_id,
            "patient_id": patient_id,
            "eye_side": eye_side,
            "camera_profile": camera_profile,
            "quality_grade": record.quality_grade.value,
            "quality_score": round(quality_score, 4),
            "quality_passed": _gradable,
            "rejection_reasons": record.rejection_reasons,
            "suspected_clinical_cause": record.suspected_clinical_cause,
            "dr_grade": dr_grade,
            "dr_label": dr_label,
            "prediction_score": round(conf, 4) if conf is not None else None,
            "probabilities": probs,
            "is_referable": is_ref,
            "model_backend": self.dr_classifier.get_backend(),
            "inference_time_ms": inference_time_ms,
            "requires_human_review": record.human_review_required,
            "human_review_type": record.human_review_type.value,
            "human_review_reason": record.human_review_reason,
            "confidence_flags": _confidence_flags_with_ood(
                getattr(record.confidence_assessment, "flags", []) if record.confidence_assessment else [],
                probs,
            ),
            "action_recommendation": record.action,
            "original_image_url": orig_url,
            "gradcam_overlay_url": gradcam_url,
            "gradcam_target_layer": target_layer,
            "vessel_density_pct": vessel_density_pct,
            "microaneurysm_count": microaneurysm_count,
            "csme_risk": csme_risk,
            "min_fovea_distance_px": min_fovea_distance_px,
            "patient_plain_language_summary": plain_summary,
            "created_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        }

    # -------------------------------------------------------------------------
    # 3. Upstream Diabetes Risk Screening
    # -------------------------------------------------------------------------
    def evaluate_diabetes_risk(self, data: dict[str, Any]) -> dict[str, Any]:
        if data.get("age") is None or data.get("bmi") is None or data.get("family_history") is None:
            raise ValueError("age, bmi and family_history are required for risk evaluation.")
        profile = PatientClinicalProfile(
            patient_id=data.get("patient_id") or "PT-DEMO",
            age=data.get("age"),
            gender=data.get("gender", "Unknown"),
            bmi=data.get("bmi"),
            family_history_diabetes=data.get("family_history"),
            physical_activity=data.get("physical_activity", "Moderate"),
            symptoms=data.get("symptoms", []),
            hba1c_pct=data.get("hba1c"),
            fasting_glucose_mg_dl=data.get("fasting_glucose"),
            random_glucose_mg_dl=data.get("random_glucose"),
            known_diabetes_years=data.get("known_diabetes_years"),
        )
        assessment = self.risk_model.evaluate(profile)

        # Clear patient-friendly guidance distinguishing risk from diagnosis
        if assessment.risk_level.value == "HIGH":
            patient_guide = (
                "The health checkup shows elevated risk factors for diabetes. "
                "Clinical laboratory testing (blood sugar) and an eye screening are recommended."
            )
        elif assessment.risk_level.value == "MODERATE":
            patient_guide = (
                "Moderate lifestyle risk factors detected. Periodic blood glucose checkup "
                "and dietary consultation are recommended."
            )
        else:
            patient_guide = (
                "Low risk profile detected. Maintain regular physical activity and a balanced diet. "
                "Rescreen annually."
            )

        return {
            "risk_score": round(assessment.risk_score, 1),
            "risk_level": assessment.risk_level.value,
            "pathway": assessment.pathway.value,
            "risk_source": assessment.risk_source,
            "clinical_rationale": assessment.clinical_rationale,
            "action_recommendation": assessment.action_recommendation,
            "patient_friendly_guidance": patient_guide,
        }

    def _generate_plain_patient_summary(self, quality: QualityGrade, dr_grade: int | None, is_referable: bool) -> str:
        if quality == QualityGrade.BAD:
            return "The photograph was not clear enough for the computer to examine your retina. Please take a new photograph."
        if quality == QualityGrade.BORDERLINE and dr_grade is None:
            return "The photo quality is slightly marginal. A health worker or doctor will review this image."
        if dr_grade is None or dr_grade == 0:
            return "Normal screening result: No signs of diabetic damage in the retinal blood vessels. Rescreen in 12 months."
        elif dr_grade == 1:
            return "Mild blood vessel changes noted. Regular blood sugar control and a follow-up eye exam in 6 months are advised."
        elif dr_grade == 2:
            return "Noticeable diabetic retinopathy changes detected. A referral has been created for an eye specialist review."
        elif dr_grade >= 3:
            return "Significant retinal changes detected requiring prompt evaluation by an ophthalmologist within 2–4 weeks."
        return "Screening completed. Please discuss this report with your healthcare provider."
