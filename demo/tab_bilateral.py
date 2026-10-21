"""Bilateral staging & longitudinal progression tracker tab (tab 2).

Extracted verbatim from demo/app.py lines 1405-1647.
"""

import os

import numpy as np
import streamlit as st
from PIL import Image

from demo.engine import bilateral_eye_model_grade


def _od_sample_path(project_root: str, sample: str) -> str:
    if "Grade 2" in sample:
        return os.path.join(
            project_root, "test_samples", "04_section24_demo_scenarios", "scenario_1_good.jpg"
        )
    if "Grade 1" in sample:
        return os.path.join(
            project_root,
            "test_samples",
            "04_section24_demo_scenarios",
            "scenario_3_borderline.jpg",
        )
    if "Grade 0" in sample:
        return os.path.join(
            project_root,
            "test_samples",
            "01_real_clinical_fundus",
            "real_clinical_fundus_patient1.jpg",
        )
    return os.path.join(
        project_root, "test_samples", "04_section24_demo_scenarios", "scenario_2_bad.jpg"
    )


def _os_sample_path(project_root: str, sample: str) -> str:
    if "Grade 3" in sample:
        return os.path.join(
            project_root,
            "test_samples",
            "04_section24_demo_scenarios",
            "scenario_4_uncertain.jpg",
        )
    if "Grade 2" in sample or "Scenario 1" in sample:
        return os.path.join(
            project_root, "test_samples", "04_section24_demo_scenarios", "scenario_1_good.jpg"
        )
    if "Grade 1" in sample or "Scenario 3" in sample:
        return os.path.join(
            project_root,
            "test_samples",
            "04_section24_demo_scenarios",
            "scenario_3_borderline.jpg",
        )
    return os.path.join(
        project_root,
        "test_samples",
        "01_real_clinical_fundus",
        "real_clinical_fundus_patient1.jpg",
    )


def _eye_biomarkers(segmenter, img_path: str):
    try:
        eye_pil = Image.open(img_path).convert("RGB")
        eye_struct = segmenter.segment_structures(np.array(eye_pil))
        mas = len(eye_struct.microaneurysm_candidates)
        fovea_prox = (
            int(eye_struct.min_fovea_distance_px)
            if eye_struct.min_fovea_distance_px is not None
            else "N/A"
        )
        vessel_pct = round(eye_struct.vessel_density_pct, 1)
        return mas, fovea_prox, vessel_pct, False
    except Exception:
        return "N/A", "N/A", "N/A", True


def render_bilateral_tab(
    tab, project_root: str, router, segmenter, camera_hardware: str, threshold_profile: str
) -> None:
    with tab:
        st.subheader("👁️ Bilateral Retinal Staging & Longitudinal Progression Tracker")
        st.caption(
            "Clinical standard ETDRS protocol: Paired evaluation of Right Eye (OD) and Left Eye (OS) "
            "plus multi-year disease progression tracking for diabetic retinopathy surveillance."
        )

        st.markdown("### Part 1: Bilateral Eye Staging (Oculus Dexter & Oculus Sinister)")
        st.caption(
            "Dropdowns select sample captures only. Every grade below is a live "
            "Model 1 quality gate + Model 2 classifier prediction on that capture — "
            "never a preset label."
        )

        bi_col1, bi_col2 = st.columns(2)

        with bi_col1:
            st.markdown("#### 👁️‍🗨️ Right Eye (OD - Oculus Dexter)")
            od_sample = st.selectbox(
                "Select OD Retinal Image",
                [
                    "Scenario 1: Moderate NPDR (Grade 2 - Real Fundus)",
                    "Scenario 3: Mild NPDR (Grade 1 - Real Fundus)",
                    "Healthy / Grade 0 (No DR)",
                    "Degraded / Defocused Capture (BAD)",
                ],
                key="od_select",
            )
            od_img_path = _od_sample_path(project_root, od_sample)
            if od_img_path and os.path.exists(od_img_path):
                od_grade, od_status = bilateral_eye_model_grade(
                    od_img_path, router, camera_hardware, threshold_profile
                )
            else:
                od_grade, od_status = None, "UNGRADABLE (sample missing)"

            od_mas, od_fovea_prox, od_vessel_pct, od_failed = "N/A", "N/A", "N/A", False
            if od_img_path and os.path.exists(od_img_path) and od_grade is not None:
                od_mas, od_fovea_prox, od_vessel_pct, od_failed = _eye_biomarkers(
                    segmenter, od_img_path
                )

            if od_failed:
                st.error(
                    "**OD Analysis failed:** segmentation error — biomarkers unavailable, not estimated."
                )
            st.info(
                f"**OD Diagnosis:** {od_status}\n- Segmented Microaneurysms: {od_mas}\n- Fovea Proximity: {od_fovea_prox} px\n- Retinal Vessel Density: {od_vessel_pct}%"
            )

        with bi_col2:
            st.markdown("#### 👁️‍🗨️ Left Eye (OS - Oculus Sinister)")
            os_sample = st.selectbox(
                "Select OS Retinal Image",
                [
                    "Scenario 3: Mild NPDR (Grade 1 - Real Fundus)",
                    "Scenario 1: Moderate NPDR (Grade 2 - Real Fundus)",
                    "Healthy / Grade 0 (No DR)",
                    "Severe NPDR / Grade 3 (High Risk)",
                ],
                key="os_select",
            )
            os_img_path = _os_sample_path(project_root, os_sample)
            if os_img_path and os.path.exists(os_img_path):
                os_grade, os_status = bilateral_eye_model_grade(
                    os_img_path, router, camera_hardware, threshold_profile
                )
            else:
                os_grade, os_status = None, "UNGRADABLE (sample missing)"

            os_mas, os_fovea_prox, os_vessel_pct, os_failed = "N/A", "N/A", "N/A", False
            if os_img_path and os.path.exists(os_img_path) and os_grade is not None:
                os_mas, os_fovea_prox, os_vessel_pct, os_failed = _eye_biomarkers(
                    segmenter, os_img_path
                )

            if os_failed:
                st.error(
                    "**OS Analysis failed:** segmentation error — biomarkers unavailable, not estimated."
                )
            st.info(
                f"**OS Diagnosis:** {os_status}\n- Segmented Microaneurysms: {os_mas}\n- Fovea Proximity: {os_fovea_prox} px\n- Retinal Vessel Density: {os_vessel_pct}%"
            )

        # Composite Patient Staging
        valid_grades = [g for g in [od_grade, os_grade] if g is not None]
        ungraded_eyes = [n for n, g in (("OD", od_grade), ("OS", os_grade)) if g is None]
        if ungraded_eyes:
            st.divider()
            st.markdown("#### 🏥 Overall Composite Patient Diagnosis (Worst-Eye Rule)")
            st.warning(
                f"⚠️ **INCOMPLETE STAGING — {' & '.join(ungraded_eyes)} ungradable, recapture required.**\n\n"
                "- A worst-eye verdict cannot be issued until both eyes are graded. "
                "Do not treat the graded eye's result as a whole-patient clearance."
            )
        if valid_grades:
            overall_grade = max(valid_grades)
            is_referable = overall_grade >= 2

            st.divider()
            st.markdown("#### 🏥 Overall Composite Patient Diagnosis (Worst-Eye Rule)")
            if is_referable:
                st.error(
                    f"🚨 **Patient DR Staging: Grade {overall_grade} (REFERABLE RETINOPATHY)**\n\n"
                    f"- Clinical Protocol: Governed by worst eye (`max(OD={od_grade}, OS={os_grade})`).\n"
                    f"- Tele-referral: Action required within 14 days at District Hospital Eye Unit."
                )
            else:
                if ungraded_eyes:
                    st.info(
                        f"ℹ️ **Graded eye: Grade {overall_grade} (below referral threshold) — "
                        f"but whole-patient staging is INCOMPLETE until "
                        f"{' & '.join(ungraded_eyes)} is recaptured and graded. "
                        "No routine-clearance decision yet.**"
                    )
                else:
                    st.success(
                        f"🟢 **Patient DR Staging: Grade {overall_grade} (NON-REFERABLE)**\n\n"
                        f"- Clinical Protocol: Both eyes below treatment threshold. Routine 12-month rescreening."
                    )

            if od_grade is not None and os_grade is not None and abs(od_grade - os_grade) >= 2:
                st.warning(
                    f"⚠️ **Marked Inter-Ocular Asymmetry Detected (OD: Grade {od_grade} vs OS: Grade {os_grade})**\n\n"
                    f"Marked asymmetry in diabetic retinopathy is atypical and warrants clinical investigation for "
                    f"ipsilateral carotid artery stenosis or prior unilateral laser/vitrectomy."
                )

        st.divider()
        st.markdown("### Part 2: Longitudinal Surveillance & Progression Tracker")
        st.caption(
            "Tracking a patient's multi-year screening history across rural health check-up camps. "
            "⚠️ Illustrative vignette below — synthetic cohort data for UI demonstration, "
            "not this patient's record; therapy wording is illustrative, not a recommendation."
        )

        # Historical cohort data
        history_data = {
            "Screening Date": ["14-Mar-2024", "18-Mar-2025", "07-Sep-2026 (Today)"],
            "Encampment Location": [
                "Vellore PHC Camp",
                "Vellore Sub-Centre",
                "Ranipet District Camp",
            ],
            "HbA1c (%)": [6.8, 7.6, 8.9],
            "OD Grade": [0, 1, 2],
            "OS Grade": [0, 1, 1],
            "Overall Grade": [0, 1, 2],
            "Total MA Count": [0, 5, 15],
            "Status / Velocity": [
                "Normal Baseline",
                "Early Onset (+1 Step)",
                "Accelerated Progression (+1 Step)",
            ],
        }
        st.dataframe(history_data, width="stretch")

        col_chart1, col_chart2 = st.columns(2)
        with col_chart1:
            st.markdown("**📈 Severity Grade Progression over Time**")
            chart_data_grade = {"Grade": [0, 1, 2]}
            st.line_chart(chart_data_grade)
        with col_chart2:
            st.markdown("**🩸 Microaneurysm Count vs HbA1c Correlation**")
            chart_data_ma = {"HbA1c (%)": [6.8, 7.6, 8.9], "Microaneurysms": [0, 5, 15]}
            st.bar_chart(chart_data_ma)

        st.warning(
            "⚡ **Clinical Surveillance Alert:** Patient demonstrates rapid DR progression (+2 ETDRS severity grades in 2.5 years) "
            "strongly correlated with glycemic worsening (HbA1c increased from 6.8% to 8.9%). "
            "Recommend immediate escalation of oral hypoglycemics / insulin therapy in addition to retinal referral."
        )
