"""Clinical wizard screens 1 (intake) and 2 (capture + quality gate).

Extracted verbatim from demo/app.py lines 615-928. Callers must invoke
these inside the tab container context and in the original order.
"""

import streamlit as st

from demo.clinical_prep import uploaded_image_ingestion
from src.clinical_risk import ScreeningPathway
from src.pipeline.schema import QualityGrade

_STEPS_META = [
    (1, "📋 1. Patient Intake", "Demographics & Risk Model"),
    (2, "📸 2. Retinal Scan", "Hardware & Quality Gate"),
    (3, "🔬 3. AI Triage & Audit", "Grading & Grad-CAM Heatmap"),
    (4, "📄 4. Referral Hub", "SMS, PDF & ABDM EMR"),
]


def render_wizard_header(curr_step: int) -> None:
    """Dynamic Stepper Navigation Header (original lines 406-451)."""
    stepper_cols = st.columns(4)
    for idx, (s_num, s_title, s_sub) in enumerate(_STEPS_META):
        with stepper_cols[idx]:
            if s_num == curr_step:
                st.markdown(
                    f"""
                <div style="padding: 10px 14px; background: linear-gradient(135deg, #1A56DB 0%, #1E429F 100%); color: white; border-radius: 10px; border: 1px solid #1A56DB; box-shadow: 0 4px 10px rgba(26,86,219,0.25);">
                    <div style="font-size: 10px; font-weight: 700; color: #93C5FD; text-transform: uppercase;">ACTIVE SCREEN</div>
                    <div style="font-size: 14px; font-weight: 700;">{s_title}</div>
                    <div style="font-size: 11px; color: #E0E7FF;">{s_sub}</div>
                </div>
                """,
                    unsafe_allow_html=True,
                )
            elif s_num < curr_step:
                st.markdown(
                    f"""
                <div style="padding: 10px 14px; background: var(--secondary-background-color); border: 1px solid rgba(16, 185, 129, 0.4); border-radius: 10px; color: var(--text-color);">
                    <div style="font-size: 10px; font-weight: 700; color: #10B981;">COMPLETED ✓</div>
                    <div style="font-size: 14px; font-weight: 600;">{s_title}</div>
                    <div style="font-size: 11px; opacity: 0.7;">{s_sub}</div>
                </div>
                """,
                    unsafe_allow_html=True,
                )
            else:
                st.markdown(
                    f"""
                <div style="padding: 10px 14px; background: var(--secondary-background-color); border: 1px solid rgba(128, 128, 128, 0.15); border-radius: 10px; color: var(--text-color); opacity: 0.6;">
                    <div style="font-size: 10px; font-weight: 600; opacity: 0.6;">UPCOMING</div>
                    <div style="font-size: 14px; font-weight: 600;">{s_title}</div>
                    <div style="font-size: 11px; opacity: 0.6;">{s_sub}</div>
                </div>
                """,
                    unsafe_allow_html=True,
                )

    st.markdown("<div style='height: 14px;'></div>", unsafe_allow_html=True)


def render_screen_1(patient_profile, assessment) -> None:
    """Upstream Patient Clinical Intake (original lines 615-718)."""
    st.subheader("Stage 1: Upstream Patient Clinical Intake (Zero-Hardware Screen)")
    st.caption(
        "Community health worker triage (ASHA/PHC nurse) in 90 seconds before camera engagement."
    )

    col_p1, col_p2, col_p3 = st.columns(3)
    with col_p1:
        st.session_state.p_id = st.text_input("Patient ID", value=st.session_state.p_id)
        st.session_state.p_age = st.slider("Patient Age", 18, 90, value=st.session_state.p_age)
        st.session_state.p_gender = st.selectbox(
            "Biological Sex",
            ["Male", "Female", "Other"],
            index=["Male", "Female", "Other"].index(st.session_state.p_gender),
        )
        st.session_state.p_bmi = st.slider(
            "Body Mass Index (BMI kg/m²)",
            15.0,
            45.0,
            value=st.session_state.p_bmi,
            step=0.1,
            help="ICMR South Asian cutoff: Overweight >= 23.0, Obese >= 27.5",
        )

    with col_p2:
        st.session_state.p_fam_hist = st.checkbox(
            "First-Degree Family History of Diabetes",
            value=st.session_state.p_fam_hist,
        )
        st.session_state.p_activity = st.selectbox(
            "Physical Activity Level",
            ["Sedentary", "Moderate", "Vigorous"],
            index=["Sedentary", "Moderate", "Vigorous"].index(st.session_state.p_activity),
        )
        st.session_state.p_symptoms = st.multiselect(
            "Reported Symptoms",
            [
                "Polyuria (Frequent urination)",
                "Polydipsia (Excessive thirst)",
                "Blurry vision",
                "Unexplained weight loss",
                "Fatigue",
            ],
            default=st.session_state.p_symptoms,
        )

    with col_p3:
        st.session_state.p_has_diabetes = st.checkbox(
            "Previously Diagnosed with Diabetes?",
            value=st.session_state.p_has_diabetes,
        )
        if st.session_state.p_has_diabetes:
            st.session_state.p_known_years = st.number_input(
                "Years Living with Diabetes",
                min_value=0.0,
                max_value=40.0,
                value=st.session_state.p_known_years,
            )
        st.session_state.p_hba1c = st.number_input(
            "Laboratory HbA1c (%) [if tested]",
            min_value=4.0,
            max_value=16.0,
            value=st.session_state.p_hba1c,
            step=0.1,
        )
        st.session_state.p_fasting_glucose = st.number_input(
            "Fasting Plasma Glucose (mg/dL) [if tested]",
            min_value=60.0,
            max_value=400.0,
            value=st.session_state.p_fasting_glucose,
            step=1.0,
        )

    # Risk Model Verdict Banner
    st.markdown("#### Clinical Risk Stratification")
    col_r1, col_r2 = st.columns([1, 2])
    with col_r1:
        st.metric(
            "Stage 1 Risk Score (Random Forest ML)",
            f"{assessment.risk_score:.0f}/100",
            f"Tier: {assessment.risk_level.value}",
        )
        if assessment.pathway == ScreeningPathway.RETINAL_SCREENING_INDICATED:
            st.success("Pathway: Retinal Screening Indicated")
        elif assessment.pathway == ScreeningPathway.CLINICAL_TESTING_REQUIRED:
            st.warning("Pathway: Clinical Lab Testing Required")
        else:
            st.info("Pathway: Routine Lifestyle Guidance")

    with col_r2:
        st.info(f"**Clinical Next Step:** {assessment.action_recommendation}")
        if assessment.clinical_rationale:
            st.caption(f"**Model Rationale:** {' • '.join(assessment.clinical_rationale)}")

    st.divider()
    _, nav_c2 = st.columns([2, 1])
    with nav_c2:
        if st.button(
            "Proceed to Retinal Capture 📸 →",
            type="primary",
            width="stretch",
        ):
            st.session_state.wizard_step = 2
            st.rerun()


def render_screen_2(
    gate_config, record, image_to_process, router, segmenter, project_root: str
) -> None:
    """Retinal Acquisition & Quality Gate (original lines 723-928)."""
    st.subheader("Stage 2: Retinal Image Ingestion & Real-Time Quality Gate (MathWorks Req 1)")
    st.caption("ISO-standard quality check executed in 0.12s before running heavy neural networks.")

    col_input_type, col_source = st.columns([1, 2])
    with col_input_type:
        st.radio(
            "Fundus Ingestion Mode",
            ["Curated Field Test Pack", "Upload Custom Capture"],
            index=["Curated Field Test Pack", "Upload Custom Capture"].index(
                st.session_state.input_mode
            ),
            key="input_mode",
        )

    with col_source:
        if st.session_state.input_mode == "Curated Field Test Pack":
            st.selectbox(
                "Select Curated Field Case",
                [
                    "Case 1: Clean Diagnostic Quality (Patient 1 — Hospital data)",
                    "Case 2: Degraded Capture (Severe Defocus & Media Opacity)",
                    "Case 3: Borderline Capture (Marginal illumination/contrast)",
                    "Case 4: Severe Retinal Lesions (High-Risk Proliferative Signs)",
                    "Case 5: Adversarial Non-Fundus Input (Negative Control)",
                ],
                index=[
                    "Case 1: Clean Diagnostic Quality (Patient 1 — Hospital data)",
                    "Case 2: Degraded Capture (Severe Defocus & Media Opacity)",
                    "Case 3: Borderline Capture (Marginal illumination/contrast)",
                    "Case 4: Severe Retinal Lesions (High-Risk Proliferative Signs)",
                    "Case 5: Adversarial Non-Fundus Input (Negative Control)",
                ].index(st.session_state.chosen_case),
                key="chosen_case",
            )
        else:
            uploaded_image_ingestion(router, segmenter, gate_config, project_root)

    # Viewport + Quality Gate Assessment
    st.divider()
    q_col_img, q_col_verdict = st.columns([1.2, 1.8])

    with q_col_img:
        st.markdown("##### 📷 Live Retinal Capture Viewport")
        if image_to_process is not None:
            st.image(
                image_to_process,
                caption=f"Captured Scan • {gate_config.camera_hardware.split()[0]} Preset",
                width="stretch",
            )

    with q_col_verdict:
        st.markdown("##### 🛡️ Model 1: ISO Optical Quality Assessment")
        if record is not None:
            if record.quality_grade == QualityGrade.GOOD:
                st.success(
                    "**Quality Status:** GOOD (Reliable Original Certified • Blur Score Optimal)"
                )
                st.caption(
                    "✅ Image passed sharpness, illumination, contrast, and field-of-view thresholds."
                )
            elif record.quality_grade == QualityGrade.BORDERLINE:
                st.warning(
                    f"**Quality Status:** BORDERLINE (Reassessment: {record.reassessment_outcome.value})"
                )
                st.caption(
                    "🟡 Marginal capture. Permitted for triage under supervised clinical review."
                )
            else:
                st.error(
                    "🛑 **Quality Status:** BAD — Fails Reliability Gate (Diagnostic Leakage Safeguard)"
                )
                st.caption(
                    "🚫 Strict medical guardrail active: Ungradable captures are prevented from reaching disease classification."
                )

            suspected_cause = getattr(record, "suspected_clinical_cause", None)
            if suspected_cause:
                st.info(f"**Suspected Cause:** {suspected_cause}")

            qm = getattr(record, "quality_metrics", None)
            if qm and qm.raw_scores:
                ml_q = qm.raw_scores.get("ml_quality_score")
                q_eng = qm.raw_scores.get("quality_engine", "Adaptive Fusion")
                if ml_q is not None:
                    col_m1, col_m2 = st.columns(2)
                    with col_m1:
                        st.metric("ML Quality Index", f"{ml_q * 100:.1f}%", f"Engine: {q_eng}")
                    with col_m2:
                        st.metric(
                            "Retinal ROI Coverage",
                            f"{qm.fov_ratio * 100:.1f}%",
                            f"Sharpness: {qm.sharpness_score:.1f}",
                        )

            if record.quality_grade != QualityGrade.GOOD:
                with st.expander(
                    "💡 ASHA / Field Operator Real-Time Alignment Guide",
                    expanded=True,
                ):
                    st.markdown(
                        "**Immediate Corrective Actions:**\n"
                        "1. **Blur / Defocus:** Adjust diopter dial on camera (+/- 2D) or stabilize forehead against patient brow.\n"
                        "2. **Small Pupil / Inadequate Light:** Dim room light for 3 minutes to achieve natural physiological dilation.\n"
                        "3. **Crescent Shadow:** Move camera 3–5 mm closer to patient eye and center illumination on pupil."
                    )
                    st.markdown(
                        '> 🔊 **Hindi Voice Guidance:** *"कृपया कैमरा 2 सेमी पास लाएं और मरीज को हरी बत्ती पर देखने को कहें।"*'
                    )

    st.divider()
    s2_b1, _, s2_b3 = st.columns([1, 1, 1.2])
    with s2_b1:
        if st.button("← Back to Patient Intake", width="stretch"):
            st.session_state.wizard_step = 1
            st.rerun()
    with s2_b3:
        if record is not None and record.quality_grade != QualityGrade.BAD:
            if st.button(
                "Run Multimodal AI Triage ⚡ →",
                type="primary",
                width="stretch",
            ):
                st.session_state.wizard_step = 3
                st.rerun()
        else:
            st.button(
                "🚫 AI Triage Locked (Fix Quality First)",
                disabled=True,
                width="stretch",
            )
