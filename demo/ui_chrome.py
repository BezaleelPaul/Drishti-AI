"""Static page chrome + top configuration strip for the ELYTRIVA demo.

Extracted verbatim from demo/app.py lines 45-271. All st.* calls here must
execute in the original order: page config -> CSS -> header -> config
strip. Widgets inside ``render_config_strip`` keep identical session keys
and return values.
"""

import streamlit as st

_NAVY_HEADER_HTML = """
<div style="display: flex; justify-content: space-between; align-items: center; padding: 14px 24px; background: linear-gradient(135deg, #0A2540 0%, #1A365D 100%); border-radius: 14px; margin-bottom: 16px; box-shadow: 0 4px 16px rgba(10, 37, 64, 0.18); color: white;">
    <div style="display: flex; align-items: center; gap: 14px;">
        <div style="background: rgba(255, 255, 255, 0.12); padding: 8px 12px; border-radius: 10px; font-size: 24px; backdrop-filter: blur(4px);">👁️</div>
        <div>
            <div style="font-size: 20px; font-weight: 800; letter-spacing: -0.3px; color: #FFFFFF; display: flex; align-items: center; gap: 8px;">
                ELYTRIVA <span style="font-size: 11px; font-weight: 700; background: #0D9488; padding: 3px 8px; border-radius: 6px; text-transform: uppercase; letter-spacing: 0.5px;">SIH2026 • MathWorks</span>
            </div>
            <div style="font-size: 13px; color: #94A3B8;">Explainable Retinal Screening & District Telemedicine Queuing Engine</div>
        </div>
    </div>
    <div style="display: flex; align-items: center; gap: 16px;">
        <div style="text-align: right;">
            <div style="font-size: 12px; font-weight: 600; color: #38BDF8;">ABDM & Ayushman Bharat Compliant</div>
            <div style="font-size: 11px; color: #94A3B8;">TRL 6 Clinical Triage • ≤1.4s Edge Turnaround</div>
        </div>
        <div style="background: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.6); color: #34D399; font-size: 12px; font-weight: 700; padding: 6px 12px; border-radius: 20px; display: flex; align-items: center;">
            <span class="radar-dot"></span>ENGINE ACTIVE
        </div>
    </div>
</div>
"""

_CSS = """
<style>
    /* Google Fonts Import */
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;700&display=swap');

    /* 1. Completely remove Streamlit sidebar and collapse toggle */
    [data-testid="stSidebar"],
    [data-testid="stSidebarNav"],
    [data-testid="stSidebarCollapsedControl"] {
        display: none !important;
        width: 0 !important;
    }

    /* 2. Hide Streamlit top header, deploy button, hamburger menu & footer */
    header[data-testid="stHeader"],
    #MainMenu,
    footer,
    .stDeployButton,
    [data-testid="stToolbar"],
    [data-testid="stDecoration"] {
        display: none !important;
        height: 0 !important;
    }

    /* 3. Modern container layout & smooth font */
    .block-container {
        padding-top: 1.2rem !important;
        padding-bottom: 2.5rem !important;
        padding-left: 2.5rem !important;
        padding-right: 2.5rem !important;
        max-width: 1440px !important;
    }

    /* 4. Radar Dot Pulsating Animation */
    .radar-dot {
        display: inline-block;
        width: 9px;
        height: 9px;
        background-color: #10B981;
        border-radius: 50%;
        margin-right: 6px;
        box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
        animation: none;
        vertical-align: middle;
    }
    @keyframes pulse-radar {
        0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.8); }
        70% { box-shadow: 0 0 0 10px rgba(16, 185, 129, 0); }
        100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
    }

    /* Keep the retinal capture stable while Streamlit refreshes widgets. */
    [data-testid="stImage"] img,
    [data-testid="stImage"] {
        animation: none !important;
        transition: none !important;
    }

    /* 5. Adaptive Navigation Tabs (Dark/Light mode compliant) */
    .stTabs [data-baseweb="tab-list"] {
        gap: 8px;
        background-color: var(--secondary-background-color) !important;
        padding: 6px;
        border-radius: 12px;
        border: 1px solid rgba(128, 128, 128, 0.2);
        margin-bottom: 1.2rem;
    }

    .stTabs [data-baseweb="tab"] {
        height: 42px;
        white-space: pre-wrap;
        background-color: transparent;
        border-radius: 8px;
        color: var(--text-color) !important;
        opacity: 0.7;
        font-weight: 600;
        font-size: 14px;
        padding: 0 20px;
        border: none !important;
        transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .stTabs [data-baseweb="tab"]:hover {
        opacity: 1.0;
        background-color: rgba(128, 128, 128, 0.12);
    }

    .stTabs [aria-selected="true"] {
        background-color: var(--background-color) !important;
        color: var(--text-color) !important;
        opacity: 1.0 !important;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08) !important;
        border: 1px solid rgba(128, 128, 128, 0.18) !important;
    }

    /* 6. Card & Metric Adaptive Theme Colors (No white-on-white clash) */
    div[data-testid="stMetric"], .stMetric {
        background-color: var(--secondary-background-color) !important;
        border: 1px solid rgba(128, 128, 128, 0.2) !important;
        border-radius: 12px;
        padding: 14px 18px;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
        transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1) !important;
    }
    div[data-testid="stMetric"]:hover {
        transform: translateY(-2px);
        box-shadow: 0 10px 20px -3px rgba(0, 0, 0, 0.12);
        border-color: #0D9488 !important;
    }
    div[data-testid="stMetricLabel"] p,
    div[data-testid="stMetricLabel"] label {
        color: var(--text-color) !important;
        opacity: 0.8 !important;
    }
    div[data-testid="stMetricValue"] div {
        color: var(--text-color) !important;
        font-weight: 700 !important;
    }

    /* 7. Modern Button Glow & Hover Transitions */
    .stButton > button {
        border-radius: 10px !important;
        font-weight: 600 !important;
        padding: 0.55rem 1.2rem !important;
        transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1) !important;
    }
    .stButton > button:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 14px rgba(26, 86, 219, 0.18);
    }
    .stButton > button:active {
        transform: translateY(0px);
    }
</style>
"""


def render_page_chrome() -> None:
    """Page config + custom CSS + animated header (order-sensitive)."""
    st.set_page_config(
        page_title="ELYTRIVA: Explainable Retinal Screening & District Telemedicine",
        page_icon="👁️",
        layout="wide",
        initial_sidebar_state="collapsed",
    )
    st.markdown(_CSS, unsafe_allow_html=True)
    st.markdown(_NAVY_HEADER_HTML, unsafe_allow_html=True)


def render_config_strip():
    """Field camera hardware & screening profile configuration widgets.

    Returns (camera_hardware, threshold_profile, recapture_attempt_count,
    enable_clahe_enhancer, enable_segmentation).
    """
    with st.expander(
        "⚙️ Field Camera Hardware & Edge Screening Profile (Click to Configure)",
        expanded=False,
    ):
        col_cfg1, col_cfg2, col_cfg3 = st.columns([1.5, 1.2, 1.0])
        with col_cfg1:
            camera_hardware = st.selectbox(
                "📷 Rural Camera Hardware Model",
                [
                    "Forus 3nethra Classic (Indian PHC Non-Mydriatic)",
                    "Remidio Fundus on Phone (Handheld Smartphone)",
                    "Volk iNview (20D Portable Condensing Lens)",
                    "Standard Desktop Fundus Camera (Clinical Tabletop)",
                ],
                help="Tunes optical quality thresholds specifically to the sensor & illumination profile of the camera.",
            )
        with col_cfg2:
            threshold_profile = st.selectbox(
                "Quality Gate Operating Strictness",
                [
                    "Balanced (Standard PHC Setting)",
                    "Permissive (Specialist Clinic Over-Read)",
                    "Conservative (Autonomous Screening)",
                ],
                help="Adjusts strictness. Permissive allows borderline captures with visible pathology to be graded under clinical supervision.",
            )
        with col_cfg3:
            recapture_attempt_count = st.number_input(
                "Patient Recapture Attempts (Max 2)",
                min_value=0,
                max_value=2,
                value=0,
                help="Enforces hard cap of 2 recaptures per patient session. Reaching cap escalates to human review.",
            )

        col_chk1, col_chk2 = st.columns(2)
        with col_chk1:
            enable_clahe_enhancer = st.checkbox(
                "Enable Adaptive CLAHE for Borderline Visuals",
                True,
                help="MathWorks Req 1: Applies adaptive CLAHE, illumination normalization, and bilateral denoising.",
            )
        with col_chk2:
            enable_segmentation = st.checkbox(
                "Extract Retinal Structures (OD, Fovea, Vessels)",
                True,
                help="MathWorks Req 2: Extracts anatomical landmarks & vessel tree for <30s audit.",
            )

    return (
        camera_hardware,
        threshold_profile,
        recapture_attempt_count,
        enable_clahe_enhancer,
        enable_segmentation,
    )
