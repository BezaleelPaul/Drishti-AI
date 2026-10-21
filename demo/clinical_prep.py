"""Clinical-tab shared preparation: patient state, image resolution, and
memoized screening inference.

Extracted verbatim from demo/app.py lines 396-610. All Streamlit widget
keys, session_state names, and hash-key semantics are unchanged.
"""

import hashlib
import os
from dataclasses import dataclass

import numpy as np
import streamlit as st
from PIL import Image

from src.clinical_risk import (
    PatientClinicalProfile,
)
from src.pipeline.schema import QualityGrade


@dataclass(frozen=True)
class GateConfig:
    """Top-bar gate configuration that keys inference memoization."""

    camera_hardware: str
    threshold_profile: str
    recapture_attempt_count: int
    enable_clahe_enhancer: bool
    enable_segmentation: bool


@dataclass(frozen=True)
class ClinicalPrep:
    """Everything the wizard screens need after preparation."""

    patient_profile: PatientClinicalProfile
    assessment: object
    image_to_process: Image.Image | None
    img_np: np.ndarray | None
    record: object | None
    seg_res: object | None


def ensure_session_defaults() -> None:
    """Wizard + patient state defaults (idempotent per session)."""
    if "wizard_step" not in st.session_state:
        st.session_state.wizard_step = 1

    if "p_id" not in st.session_state:
        st.session_state.p_id = "ARV-2026-0842"
    if "p_age" not in st.session_state:
        st.session_state.p_age = 54
    if "p_gender" not in st.session_state:
        st.session_state.p_gender = "Male"
    if "p_bmi" not in st.session_state:
        st.session_state.p_bmi = 28.4
    if "p_fam_hist" not in st.session_state:
        st.session_state.p_fam_hist = True
    if "p_activity" not in st.session_state:
        st.session_state.p_activity = "Sedentary"
    if "p_symptoms" not in st.session_state:
        st.session_state.p_symptoms = ["Blurry vision", "Fatigue"]
    if "p_has_diabetes" not in st.session_state:
        st.session_state.p_has_diabetes = True
    if "p_known_years" not in st.session_state:
        st.session_state.p_known_years = 6.0
    if "p_hba1c" not in st.session_state:
        st.session_state.p_hba1c = 8.1
    if "p_fasting_glucose" not in st.session_state:
        st.session_state.p_fasting_glucose = 152.0

    if "input_mode" not in st.session_state:
        st.session_state.input_mode = "Curated Field Test Pack"
    if "chosen_case" not in st.session_state:
        st.session_state.chosen_case = (
            "Case 1: Clean Diagnostic Quality (Patient 1 — Hospital data)"
        )


def _curated_case_path(project_root: str, case: str) -> str:
    if "Case 1" in case:
        return os.path.join(
            project_root,
            "test_samples",
            "01_real_clinical_fundus",
            "real_clinical_fundus_patient1.jpg",
        )
    if "Case 2" in case:
        return os.path.join(
            project_root,
            "test_samples",
            "02_quality_failures_and_edge_cases",
            "real_fundus_with_extreme_motion_blur.jpg",
        )
    if "Case 3" in case:
        return os.path.join(
            project_root,
            "test_samples",
            "04_section24_demo_scenarios",
            "scenario_3_borderline.jpg",
        )
    if "Case 4" in case:
        return os.path.join(
            project_root,
            "test_samples",
            "04_section24_demo_scenarios",
            "scenario_4_uncertain.jpg",
        )
    return os.path.join(
        project_root,
        "test_samples",
        "03_adversarial_non_fundus",
        "adversarial_non_fundus_blue_profile.jpg",
    )


def resolve_input_image(project_root: str) -> Image.Image | None:
    """Curated test pack selection or uploaded capture (with fallback)."""
    image_to_process = None
    if st.session_state.input_mode == "Curated Field Test Pack":
        p = _curated_case_path(project_root, st.session_state.chosen_case)
        if os.path.exists(p):
            try:
                image_to_process = Image.open(p).convert("RGB")
            except Exception as e:
                st.error(f"Curated sample failed to decode ({os.path.basename(p)}): {e}")
                image_to_process = None
    elif "uploaded_img" in st.session_state and st.session_state.uploaded_img is not None:
        image_to_process = st.session_state.uploaded_img

    if image_to_process is None:
        fallback_p = os.path.join(
            project_root,
            "test_samples",
            "01_real_clinical_fundus",
            "real_clinical_fundus_patient1.jpg",
        )
        if os.path.exists(fallback_p):
            try:
                image_to_process = Image.open(fallback_p).convert("RGB")
            except Exception as e:
                st.error(f"Fallback sample failed to decode: {e}")
                image_to_process = None
    return image_to_process


def build_patient_context(risk_model) -> tuple[PatientClinicalProfile, object]:
    patient_profile = PatientClinicalProfile(
        patient_id=st.session_state.p_id,
        age=st.session_state.p_age,
        gender=st.session_state.p_gender,
        bmi=st.session_state.p_bmi,
        family_history_diabetes=st.session_state.p_fam_hist,
        physical_activity=st.session_state.p_activity,
        symptoms=st.session_state.p_symptoms,
        fasting_glucose_mg_dl=st.session_state.p_fasting_glucose,
        hba1c_pct=st.session_state.p_hba1c,
        known_diabetes_years=st.session_state.p_known_years
        if st.session_state.p_has_diabetes
        else None,
    )
    assessment = risk_model.evaluate(patient_profile)
    return patient_profile, assessment


def run_memoized_inference(
    router, gate_config: GateConfig, img_np: np.ndarray | None, project_root: str
):
    """Run Router — memoized per (image, gate config, recaptures).

    Without this, every widget interaction re-runs the full TF pipeline.
    """
    _img_hash = (
        hashlib.sha256(np.ascontiguousarray(img_np).tobytes()).hexdigest()
        if img_np is not None
        else None
    )
    _inf_key = (
        _img_hash,
        gate_config.camera_hardware,
        gate_config.threshold_profile,
        int(gate_config.recapture_attempt_count),
        bool(gate_config.enable_segmentation),
    )
    record = None
    seg_res = None
    if img_np is not None and st.session_state.get("_inf_key") == _inf_key:
        record = st.session_state.get("_record")
        seg_res = st.session_state.get("_seg_res")
    elif img_np is not None:
        import time as _time

        _t0 = _time.perf_counter()
        with st.spinner("⚡ Grading retinal capture (quality gate → DR grade)…"):
            try:
                # Fast path: Grad-CAM heatmap is deferred (skip_gradcam) and
                # generated on demand when the Step 3 audit screen renders.
                record = router.process_image(
                    image_input=img_np,
                    recapture_attempt_count=int(gate_config.recapture_attempt_count),
                    output_dir=os.path.join(project_root, "results"),
                    skip_gradcam=True,
                )
            except Exception as e:
                st.error(f"Screening pipeline failed on this capture: {e}")
                record = None
        st.session_state._last_infer_s = _time.perf_counter() - _t0
        st.session_state._inf_key = _inf_key
        st.session_state._record = record
        st.session_state._seg_res = seg_res
    return record, seg_res


def prepare_clinical_tab(
    project_root: str, gate_config: GateConfig, risk_model, router, segmenter
) -> ClinicalPrep:
    """Sequential prep identical to the original tab-1 top block."""
    ensure_session_defaults()
    patient_profile, assessment = build_patient_context(risk_model)
    image_to_process = resolve_input_image(project_root)
    img_np = np.array(image_to_process) if image_to_process is not None else None
    record, seg_res = run_memoized_inference(router, gate_config, img_np, project_root)
    return ClinicalPrep(
        patient_profile=patient_profile,
        assessment=assessment,
        image_to_process=image_to_process,
        img_np=img_np,
        record=record,
        seg_res=seg_res,
    )


def uploaded_image_ingestion(router, segmenter, gate_config: GateConfig, project_root: str) -> None:
    """Step-2 upload widget handling (extracted from original lines 760-834)."""
    import io

    _hashlib = hashlib

    uploaded_file = st.file_uploader(
        "Upload Retinal Photograph",
        type=["jpg", "jpeg", "png"],
        key="custom_upload",
    )
    # NOTE: image_to_process/record were already computed from
    # session state EARLIER in this run (Streamlit executes
    # top-to-bottom), so a new/cleared upload must st.rerun()
    # for the viewport + verdict above to reflect it at once.
    # Reruns are guarded by hash comparison: no state change
    # means no rerun, so this can never loop.
    if uploaded_file is not None:
        try:
            # getvalue() bytes (not the stream): the uploader's
            # read position is unreliable across reruns and a
            # second Image.open on the same stream can fail.
            new_img = Image.open(io.BytesIO(uploaded_file.getvalue())).convert("RGB")
        except Exception as e:
            st.error(f"Uploaded file is not a decodable image: {e}")
            if st.session_state.get("uploaded_img") is not None:
                st.session_state.uploaded_img = None
                st.session_state.uploaded_hash = None
                st.session_state._record = None
                st.session_state._seg_res = None
                st.rerun()
            st.session_state.uploaded_img = None
            st.session_state.uploaded_hash = None
        else:
            new_np = np.array(new_img)
            new_hash = _hashlib.sha256(np.ascontiguousarray(new_np).tobytes()).hexdigest()
            if st.session_state.get("uploaded_hash") != new_hash:
                try:
                    uploaded_key = (
                        new_hash,
                        gate_config.camera_hardware,
                        gate_config.threshold_profile,
                        int(gate_config.recapture_attempt_count),
                        bool(gate_config.enable_segmentation),
                    )
                    uploaded_record = router.process_image(
                        image_input=new_np,
                        recapture_attempt_count=int(gate_config.recapture_attempt_count),
                        output_dir=os.path.join(project_root, "results"),
                        skip_gradcam=True,
                    )
                    uploaded_seg_res = None
                    if (
                        gate_config.enable_segmentation
                        and uploaded_record.quality_grade != QualityGrade.BAD
                    ):
                        uploaded_seg_res = segmenter.segment_structures(new_np)
                    # Pre-warm the memo cache: after the rerun
                    # below, the top block recomputes the same key
                    # and hits this record instead of re-running TF.
                    st.session_state.uploaded_img = new_img
                    st.session_state.uploaded_hash = new_hash
                    st.session_state._inf_key = uploaded_key
                    st.session_state._record = uploaded_record
                    st.session_state._seg_res = uploaded_seg_res
                except Exception as e:
                    st.error(f"Uploaded file is not a decodable image: {e}")
                    st.session_state.uploaded_img = None
                    st.session_state.uploaded_hash = None
                st.rerun()
    elif st.session_state.get("uploaded_img") is not None:
        # Uploader cleared (X) but a ghost image lingered in
        # state: drop it so the viewport falls back cleanly.
        st.session_state.uploaded_img = None
        st.session_state.uploaded_hash = None
        st.session_state._record = None
        st.session_state._seg_res = None
        st.rerun()
