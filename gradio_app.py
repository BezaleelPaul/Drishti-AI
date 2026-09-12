"""Drishti-AI live DR screening demo (Gradio).

Runs in two places with zero changes:
- Hugging Face ZeroGPU Space (GRADIO_SHARE unset -> local serve).
- Google Colab with a free T4 (set GRADIO_SHARE=1 -> public gradio.live link).

Slim face over the exact same pipeline as the full Streamlit platform:
Model 1 quality gate -> Model 2 EfficientNetB0 5-class DR grading (real
`final_model.keras` weights) -> Grad-CAM++ explainability -> anatomical
biomarkers.

Slim Gradio face over the exact same pipeline as the full Streamlit platform:
Model 1 quality gate -> Model 2 EfficientNetB0 5-class DR grading (real
`final_model.keras` weights) -> Grad-CAM++ explainability -> anatomical
biomarkers. Runs CPU-only (tensorflow-cpu) inside a @spaces.GPU-gated call
(ZeroGPU hardware requires the decorator; no CUDA work happens inside it).

Scope note: this Space is the *inference demo*. The full platform (patient
wizard, bilateral tracker, district simulation, PDF/FHIR referral hub) lives
in the Streamlit app: demo/app.py in the source repo.
"""

import os

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import sys
from dataclasses import replace as _dc_replace

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
from PIL import Image

import gradio as gr
import spaces

from src.classification.classifier import DRClassifier
from src.pipeline.router import ScreeningPipelineRouter
from src.pipeline.schema import QualityGrade
from src.quality.checker import ImageQualityChecker, QualityThresholds


# --------------------------------------------------------------------------
# Engine: one shared classifier (model loads ONCE), cheap per-config routers
# --------------------------------------------------------------------------
_SHARED_CLASSIFIER = None
_ROUTERS = {}


def _shared_classifier() -> DRClassifier:
    global _SHARED_CLASSIFIER
    if _SHARED_CLASSIFIER is None:
        _SHARED_CLASSIFIER = DRClassifier()
        try:  # warmup: pay TF tracing at startup, not on the first click
            _warm = (np.random.RandomState(0).rand(64, 64, 3) * 255).astype(np.uint8)
            _SHARED_CLASSIFIER.predict(_warm)
        except Exception:
            pass
    return _SHARED_CLASSIFIER


def _thresholds(camera: str, strictness: str):
    if "Remidio" in camera:
        th = QualityThresholds.for_remidio_fop()
    elif "Volk" in camera:
        th = QualityThresholds.for_volk_inview()
    elif "Desktop" in camera:
        th = QualityThresholds()
    else:
        th = QualityThresholds.for_forus_3nethra()

    if "Permissive" in strictness:
        th = _dc_replace(
            th,
            blur_good_threshold=th.blur_good_threshold * 0.9,
            blur_bad_threshold=th.blur_bad_threshold * 0.9,
            min_contrast_good=max(4.0, th.min_contrast_good - 2.0),
            min_ml_quality_good=max(0.30, th.min_ml_quality_good - 0.05),
            min_ml_quality_bad=max(0.20, th.min_ml_quality_bad - 0.05),
        )
    elif "Conservative" in strictness:
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
    return th


def _get_router(camera: str, strictness: str) -> ScreeningPipelineRouter:
    key = (camera, strictness)
    if key not in _ROUTERS:
        _ROUTERS[key] = ScreeningPipelineRouter(
            quality_checker=ImageQualityChecker(thresholds=_thresholds(camera, strictness)),
            dr_classifier=_shared_classifier(),
        )
    return _ROUTERS[key]


def _verdict_html(grade_val: int, conf: float, referable: bool) -> str:
    if referable:
        color, title = "#DC2626", "HIGH RISK — Refer to District Hospital"
    elif grade_val == 1:
        color, title = "#D97706", "MILD RETINOPATHY — 6-Month Review"
    else:
        color, title = "#16A34A", "NORMAL RETINA — Annual Routine Surveillance"
    return (
        f"<div style='padding:14px 18px;border-left:6px solid {color};"
        f"border-radius:10px;background:#f8fafc;margin:8px 0;'>"
        f"<div style='font-size:12px;font-weight:700;color:{color};'>{title}</div>"
        f"<div style='font-size:20px;font-weight:800;'>Grade {grade_val} • {conf * 100:.1f}% confidence</div>"
        f"<div style='font-size:13px;color:#475569;'>"
        f"{'Refer to ophthalmologist' if referable else 'Routine annual rescreening'}</div></div>"
    )


# ZeroGPU hardware requires at least one @spaces.GPU function, so analyze
# carries the decorator. The compute itself is CPU-only (tensorflow-cpu):
# seconds per call, far inside the per-call time cap (the earlier timeouts
# came from full-TF CUDA initialization, which no longer exists here).
@spaces.GPU
def analyze(image, camera: str, strictness: str):
    """Full screening pass (CPU compute inside a GPU-gated call). Returns 7 outputs in fixed order."""
    empty = ("Upload a retinal photograph first.", {}, "", None, None, "", "")
    if image is None:
        return empty
    try:
        img_np = np.array(image.convert("RGB"))
    except Exception as exc:
        return (f"Could not decode image: {exc}", {}, "", None, None, "", "")

    router = _get_router(camera, strictness)
    try:
        record = router.process_image(img_np, recapture_attempt_count=0, output_dir=None)
    except Exception as exc:
        return (f"Screening pipeline failed: {exc}", {}, "", None, None, "", "")

    q_text = f"Quality: {record.quality_grade.value}"
    if record.rejection_reasons:
        q_text += " — " + "; ".join(record.rejection_reasons)
    if getattr(record, "suspected_clinical_cause", None):
        q_text += f" (suspected cause: {record.suspected_clinical_cause})"

    if record.dr_prediction is None:
        html = (
            "<div style='padding:14px 18px;border-left:6px solid #6B7280;border-radius:10px;"
            "background:#f8fafc;'><b>UNGRADABLE</b> — quality gate did not certify this "
            "capture. Recapture with better focus/lighting; no DR grade issued.</div>"
        )
        return (html, {}, "", None, None, q_text, "")

    pred = record.dr_prediction
    probs = {label: float(p) for label, p in zip(DRClassifier.CLASS_LABELS, pred.probabilities)}
    conf_text = f"{pred.confidence * 100:.1f}% (top-2 margin {pred.top2_margin * 100:.1f}pp)"
    html = _verdict_html(pred.predicted_grade.value, pred.confidence, pred.is_referable)

    heatmap = None
    if record.gradcam_result is not None and record.gradcam_result.heatmap_generated:
        heatmap = record.gradcam_result.heatmap_array

    overlay, bio_text = None, ""
    try:
        seg = router.structure_segmenter.segment_structures(img_np)
        overlay = seg.annotated_overlay
        fovea = (
            f"{seg.min_fovea_distance_px:.0f} px"
            if seg.min_fovea_distance_px is not None
            else "N/A"
        )
        bio_text = (
            f"Microaneurysm candidates: {len(seg.microaneurysm_candidates)} | "
            f"Vessel density: {seg.vessel_density_pct}% | "
            f"Fovea proximity: {fovea} | CSME risk: {seg.csme_risk}"
        )
    except Exception as exc:
        bio_text = f"Segmentation unavailable: {exc}"

    return (html, probs, conf_text, heatmap, overlay, q_text, bio_text)


_BACKEND = _shared_classifier().get_backend()
_BACKEND_LINE = (
    "● Real AI model loaded (EfficientNetB0, 5-class DR grading)"
    if _BACKEND in ("keras", "pytorch")
    else "⚠ Real weights failed to load — predictions are NOT clinical"
)

CAMERAS = [
    "Forus 3nethra Classic (PHC)",
    "Remidio Fundus on Phone",
    "Volk iNview",
    "Standard Desktop Fundus",
]
STRICTNESS = [
    "Balanced (Standard PHC)",
    "Permissive (Specialist Over-Read)",
    "Conservative (Autonomous)",
]

with gr.Blocks(title="Drishti-AI — Rural DR Screening (Live)") as demo:
    gr.Markdown(
        "# 👁️ Drishti-AI — Rural Diabetic Retinopathy Screening (Live Demo)\n"
        f"**Model status:** {_BACKEND_LINE} &nbsp;•&nbsp; SIH 2026\n\n"
        "Upload a fundus photograph (or try an example) → quality gate → DR grade → "
        "Grad-CAM heatmap. Full platform (patient wizard, bilateral tracking, referral "
        "PDF/FHIR) runs in the companion Streamlit app."
    )
    with gr.Row():
        with gr.Column(scale=1):
            img_in = gr.Image(type="pil", label="Retinal photograph")
            gr.Examples(
                examples=[
                    ["test_samples/04_section24_demo_scenarios/scenario_1_good.jpg"],
                    ["test_samples/04_section24_demo_scenarios/scenario_3_borderline.jpg"],
                    ["test_samples/01_real_clinical_fundus/real_clinical_fundus_patient1.jpg"],
                    [
                        "test_samples/02_quality_failures_and_edge_cases/real_fundus_with_extreme_motion_blur.jpg"
                    ],
                ],
                inputs=[img_in],
                label="Try an example",
            )
            camera = gr.Dropdown(choices=CAMERAS, value=CAMERAS[0], label="Camera hardware")
            strictness = gr.Radio(
                choices=STRICTNESS, value=STRICTNESS[0], label="Quality gate strictness"
            )
            btn = gr.Button("Analyze", variant="primary")
        with gr.Column(scale=1):
            verdict = gr.HTML(label="Verdict")
            probs = gr.Label(label="5-class probabilities", num_top_classes=5)
            conf = gr.Textbox(label="Confidence")
            quality = gr.Textbox(label="Quality gate")
            bio = gr.Textbox(label="Biomarkers")
    with gr.Row():
        heatmap_out = gr.Image(label="Grad-CAM heatmap (Req 4)")
        overlay_out = gr.Image(label="Anatomy overlay: OD / fovea / vessels (Req 2)")

    btn.click(
        fn=analyze,
        inputs=[img_in, camera, strictness],
        outputs=[verdict, probs, conf, heatmap_out, overlay_out, quality, bio],
    )

if __name__ == "__main__":
    # Colab: set GRADIO_SHARE=1 for a public gradio.live link (free T4).
    demo.launch(share=os.environ.get("GRADIO_SHARE", "0") == "1")
