"""ELYTRIVA demo orchestrator.

Presentation is split across demo/ui_chrome (chrome + config strip),
demo/engine (cached AI engines + status banner), demo/clinical_prep
(patient/image/inference prep), demo/clinical_screens_12 and
demo/clinical_screens_34 (wizard screens), demo/tab_bilateral and
demo/tab_simulink (secondary tabs). Execution order here mirrors the
original single-file script exactly — Streamlit renders top-to-bottom.
"""

import os
import sys

# Ensure repository root is in sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# ---------------------------------------------------------------------------
# TensorFlow GPU configuration — MUST run before any src import that may
# lazily load keras/tensorflow.  Disables GPU by default to avoid screen
# flickering on low-end field PCs; opt-in via DRISHTI_USE_GPU=1.
# ---------------------------------------------------------------------------
from src.tf_config import configure_tensorflow

configure_tensorflow()

import streamlit as st

from demo.clinical_prep import GateConfig, ensure_session_defaults, prepare_clinical_tab
from demo.clinical_screens_12 import render_screen_1, render_screen_2, render_wizard_header
from demo.clinical_screens_34 import render_screen_3, render_screen_4
from demo.engine import get_screening_engine, render_model_status_banner
from demo.tab_bilateral import render_bilateral_tab
from demo.tab_simulink import render_simulink_tab, render_specs_tab
from demo.ui_chrome import render_config_strip, render_page_chrome

render_page_chrome()

(
    camera_hardware,
    threshold_profile,
    recapture_attempt_count,
    enable_clahe_enhancer,
    enable_segmentation,
) = render_config_strip()

gate_config = GateConfig(
    camera_hardware=camera_hardware,
    threshold_profile=threshold_profile,
    recapture_attempt_count=int(recapture_attempt_count),
    enable_clahe_enhancer=enable_clahe_enhancer,
    enable_segmentation=enable_segmentation,
)

# -------------------------------------------------------------------------
# Navigation: Clinical Screening Platform vs. Simulink District Simulation
# -------------------------------------------------------------------------
tab_clinical, tab_bilateral, tab_simulink, tab_specs = st.tabs(
    [
        "🩺 Integrated Clinical Screening Pipeline (Req 1, 2, 3, 4)",
        "👁️ Bilateral Staging & Longitudinal Progression Tracker",
        "📡 Simulink District Telemedicine Simulation (Req 5 - 100k Patients)",
        "📋 MathWorks Problem Compliance Matrix",
    ]
)

risk_model, router, enhancer, segmenter = get_screening_engine(camera_hardware, threshold_profile)
render_model_status_banner(router)

# =========================================================================
# TAB 1: INTEGRATED CLINICAL SCREENING PIPELINE
# =========================================================================
with tab_clinical:
    ensure_session_defaults()
    curr_step = st.session_state.wizard_step
    render_wizard_header(curr_step)

    prep = prepare_clinical_tab(PROJECT_ROOT, gate_config, risk_model, router, segmenter)

    if curr_step == 1:
        render_screen_1(prep.patient_profile, prep.assessment)
    elif curr_step == 2:
        render_screen_2(
            gate_config, prep.record, prep.image_to_process, router, segmenter, PROJECT_ROOT
        )
    elif curr_step == 3:
        render_screen_3(gate_config, prep, router, enhancer, segmenter)
    elif curr_step == 4:
        render_screen_4(prep)

render_bilateral_tab(
    tab_bilateral, PROJECT_ROOT, router, segmenter, camera_hardware, threshold_profile
)
render_simulink_tab(tab_simulink)
render_specs_tab(tab_specs)
