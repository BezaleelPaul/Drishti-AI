"""Cached AI engine factory + model-status banner for the Streamlit demo.

Extracted verbatim from demo/app.py lines 286-399 and 1368-1399. The
bilateral grading helper now takes the router explicitly instead of
closing over a module global.
"""

import os
from dataclasses import replace as _dc_replace

import numpy as np
import streamlit as st
from PIL import Image

from src.classification.classifier import DRClassifier
from src.classification.gradcam import GradCAMExplainer
from src.clinical_risk import DiabetesRiskModel
from src.pipeline.router import ScreeningPipelineRouter
from src.pipeline.schema import QualityGrade
from src.quality.checker import ImageQualityChecker, QualityThresholds
from src.quality.enhancer import AdaptiveQualityEnhancer
from src.segmentation import RetinalStructureSegmenter


@st.cache_resource
def _get_shared_classifier():
    """Loads the DRClassifier once per session, independent of camera or
    threshold-profile selection. Without this, changing camera_hardware or
    threshold_profile would invalidate get_screening_engine's cache and
    force a fresh Keras model load — a multi-second cost on CPU."""
    # Fail closed by default: the demo must never present simulated
    # predictions as screening results. DRISHTI_ALLOW_SIMULATED=1 restores
    # the old lenient fallback for offline rehearsals without weights.
    strict = os.environ.get("DRISHTI_ALLOW_SIMULATED", "0") != "1"
    classifier = DRClassifier(strict_real_weights=strict)
    gradcam_explainer = GradCAMExplainer(
        classifier_backend=classifier,
        use_gradcam_plus_plus=True,
    )
    return classifier, gradcam_explainer


@st.cache_resource
def get_screening_engine(cam_type: str, profile_mode: str):
    # Base thresholds follow the camera hardware — always applied.
    if "Forus" in cam_type:
        th = QualityThresholds.for_forus_3nethra()
    elif "Remidio" in cam_type:
        th = QualityThresholds.for_remidio_fop()
    elif "Volk" in cam_type:
        th = QualityThresholds.for_volk_inview()
    else:
        th = QualityThresholds()

    # Strictness modifier layers on top of the camera base — always applied.
    if "Permissive" in profile_mode:
        th = _dc_replace(
            th,
            blur_good_threshold=th.blur_good_threshold * 0.9,
            blur_bad_threshold=th.blur_bad_threshold * 0.9,
            min_contrast_good=max(4.0, th.min_contrast_good - 2.0),
            min_ml_quality_good=max(0.30, th.min_ml_quality_good - 0.05),
            min_ml_quality_bad=max(0.20, th.min_ml_quality_bad - 0.05),
        )
    elif "Conservative" in profile_mode:
        th = _dc_replace(
            th,
            blur_good_threshold=th.blur_good_threshold * 1.35,
            blur_bad_threshold=th.blur_bad_threshold * 1.25,
            min_brightness_good=th.min_brightness_good + 8.0,
            min_contrast_good=th.min_contrast_good + 5.0,
            min_contrast_bad=th.min_contrast_bad + 2.0,
            min_fov_ratio_good=min(0.60, th.min_fov_ratio_good + 0.08),
            min_ml_quality_good=min(0.95, th.min_ml_quality_good + 0.08),
            min_ml_quality_bad=min(0.90, th.min_ml_quality_bad + 0.08),
        )

    checker = ImageQualityChecker(thresholds=th)
    # Reuse the session-cached classifier + Grad-CAM explainer so only the
    # quality-checker thresholds change when camera/profile are adjusted.
    classifier, gradcam_explainer = _get_shared_classifier()
    router = ScreeningPipelineRouter(
        quality_checker=checker,
        dr_classifier=classifier,
        gradcam_explainer=gradcam_explainer,
    )
    risk_model = DiabetesRiskModel()
    enhancer = AdaptiveQualityEnhancer()
    segmenter = RetinalStructureSegmenter()
    # One-time warmup (this fn is @st.cache_resource: runs once per session).
    # Pays TF init + first-trace cost at page load so the first "Run AI Triage"
    # click grades in seconds instead of tens of seconds on Cloud CPU.
    try:
        _warm = (np.random.RandomState(0).rand(64, 64, 3) * 255).astype(np.uint8)
        router.dr_classifier.predict(_warm)
    except Exception:  # noqa: BLE001, S110 - warmup is best-effort, never blocks page load
        pass
    return risk_model, router, enhancer, segmenter


def render_model_status_banner(router: ScreeningPipelineRouter) -> None:
    """MODEL STATUS banner — never silently simulate. SIH judges must see
    at a glance whether grades come from the real EfficientNetB0 or the
    fallback."""
    _model_backend = router.dr_classifier.get_backend()
    _model_err = getattr(router.dr_classifier, "load_error", None)
    if _model_backend in ("keras", "pytorch", "onnx_drdetect"):
        _model_desc = (
            "`efficientnet_b0_regression_512px.onnx` DRDetect Ordinal Regression"
            if _model_backend == "onnx_drdetect"
            else "`final_model.keras` EfficientNetB0"
        )
        st.success(
            f"● MODEL STATUS: Real AI Model Loaded (`{_model_backend}` backend — "
            f"{_model_desc}, 5-class DR grading active)."
        )
    else:
        st.error(
            "⚠ MODEL NOT AVAILABLE — real DR weights failed to load; "
            "simulation mode is DISABLED for screening. "
            "Grades below are NOT clinical predictions. "
            + (f"Reason: {_model_err}" if _model_err else "Reason: no DL backend found.")
        )


@st.cache_data(show_spinner="Grading eye captures with DR model…")
def bilateral_eye_model_grade(
    img_path: str, _router: ScreeningPipelineRouter, cam_type: str = "", profile_mode: str = ""
):
    """Runs the real quality gate + DR classifier on one eye image.

    `_router` (unhashable, excluded from the cache key) carries the active
    engine; `cam_type`/`profile_mode` are part of the cache key so grades
    re-run when the gate configuration changes.

    Returns (grade:int|None, status:str). grade is None when the capture is
    ungradable (decode failure, BAD quality, or classifier error).
    """
    try:
        pil = Image.open(img_path).convert("RGB")
    except Exception as e:
        return None, f"UNGRADABLE (decode failed: {e})"
    try:
        q = _router.quality_checker.assess_image(pil)
    except Exception as e:
        return None, f"UNGRADABLE (quality check failed: {e})"
    if q.grade == QualityGrade.BAD:
        reasons = "; ".join(r.value for r in q.reasons) if q.reasons else "quality gate"
        return None, f"UNGRADABLE (Quality Rejected: {reasons})"
    borderline_note = (
        " [borderline quality — confirm on recapture]" if q.grade == QualityGrade.BORDERLINE else ""
    )
    try:
        pred = _router.dr_classifier.predict(pil)
    except Exception as e:
        return None, f"UNGRADABLE (classifier failed: {e})"
    g = pred.predicted_grade.value
    label = pred.predicted_grade.label
    suffix = " (Referable)" if g >= 2 else " (Non-referable)"
    return g, f"Grade {g} — {label}{suffix}{borderline_note}"
