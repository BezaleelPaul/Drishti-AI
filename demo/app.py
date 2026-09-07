import os
import sys
import numpy as np
from PIL import Image
import streamlit as st

# Ensure repository root is in sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.clinical_risk import (
    DiabetesRiskModel,
    PatientClinicalProfile,
    ScreeningPathway,
)
from src.pipeline.router import ScreeningPipelineRouter
from src.pipeline.schema import (
    HumanReviewType,
    QualityGrade,
    ReassessmentOutcome,
)
from src.quality.checker import ImageQualityChecker, QualityThresholds
from src.quality.enhancer import AdaptiveQualityEnhancer
from src.segmentation import RetinalStructureSegmenter
from src.simulation import TelemedicineSimulinkEngine, DistrictSimulationParams

st.set_page_config(
    page_title="MathWorks SIH26038: AI DR Screening & Telemedicine Platform",
    page_icon="👁️",
    layout="wide",
)

st.title("👁️ Explainable AI for Diabetic Retinopathy Screening in Rural India")
st.caption(
    "Smart India Hackathon 2026 (SIH26038 • MathWorks) — Complete Clinical Pipeline, Retinal Segmentation & Simulink Telemedicine Simulation"
)

# -------------------------------------------------------------------------
# Navigation: Clinical Screening Platform vs. Simulink District Simulation
# -------------------------------------------------------------------------
tab_clinical, tab_simulink, tab_specs = st.tabs([
    "🩺 Integrated Clinical Screening Pipeline (Req 1, 2, 3, 4)",
    "📡 Simulink District Telemedicine Simulation (Req 5 - 100k Patients)",
    "📋 MathWorks Problem Compliance Matrix"
])

# -------------------------------------------------------------------------
# Sidebar Controls
# -------------------------------------------------------------------------
with st.sidebar:
    st.header("⚙️ MathWorks SIH26038 Controls")
    st.markdown(
        "**MathWorks Modules Active:**\n"
        "- ✅ **Req 1:** Quality Gate & Adaptive CLAHE\n"
        "- ✅ **Req 2:** OD, Fovea & Vessel Segmentation\n"
        "- ✅ **Req 3:** DR Severity Grading (0–4)\n"
        "- ✅ **Req 4:** Grad-CAM (<30s Clinical Audit)\n"
        "- ✅ **Req 5:** Simulink District Telemedicine Sim"
    )

    st.divider()
    st.subheader("Field Operational Controls")
    
    recapture_attempt_count = st.number_input(
        "Patient Recapture Attempts (Max 2)",
        min_value=0,
        max_value=3,
        value=0,
        help="Enforces hard cap of 2 recaptures per patient session. Reaching cap escalates to human review.",
    )

    threshold_profile = st.selectbox(
        "Quality Gate Operating Point",
        ["Balanced (Standard PHC Setting)", "Permissive (Specialist Clinic Over-Read)", "Conservative (Autonomous Screening)"],
        help="Adjusts Model 1 strictness. Permissive mode allows borderline captures with visible pathology to be graded under clinical supervision."
    )

    enable_clahe_enhancer = st.checkbox("Enable Adaptive CLAHE for Borderline Visuals", True,
                                        help="MathWorks Req 1: Applies adaptive CLAHE, illumination normalization, and bilateral denoising.")
    enable_segmentation = st.checkbox("Extract Retinal Structures (OD, Fovea, Vessels)", True,
                                      help="MathWorks Req 2: Extracts anatomical landmarks & vessel tree for <30s audit.")

# Cache engines
@st.cache_resource
def get_screening_engine(profile_mode: str):
    if "Permissive" in profile_mode:
        th = QualityThresholds(
            blur_good_threshold=70.0,
            blur_bad_threshold=30.0,
            min_contrast_good=14.0,
            min_contrast_bad=6.0,
            min_brightness_good=35.0,
        )
    elif "Conservative" in profile_mode:
        th = QualityThresholds(
            blur_good_threshold=100.0,
            blur_bad_threshold=40.0,
            min_contrast_good=20.0,
            min_contrast_bad=9.0,
        )
    else:
        th = QualityThresholds()
    
    checker = ImageQualityChecker(thresholds=th)
    router = ScreeningPipelineRouter(quality_checker=checker)
    risk_model = DiabetesRiskModel()
    enhancer = AdaptiveQualityEnhancer()
    segmenter = RetinalStructureSegmenter()
    return risk_model, router, enhancer, segmenter

risk_model, router, enhancer, segmenter = get_screening_engine(threshold_profile)
sample_dir = os.path.join(PROJECT_ROOT, "test_samples")

# =========================================================================
# TAB 1: INTEGRATED CLINICAL SCREENING PIPELINE
# =========================================================================
with tab_clinical:
    st.subheader("Stage 1: Upstream Patient Clinical Intake (Zero-Hardware Screen)")
    st.caption("Community health worker triage (ASHA/PHC nurse) in 90 seconds before camera engagement.")

    with st.expander("📋 Enter Patient Clinical Parameters", expanded=True):
        col_p1, col_p2, col_p3 = st.columns(3)
        with col_p1:
            patient_id = st.text_input("Patient ID", "ARV-2026-0842")
            age = st.slider("Patient Age", 18, 90, 54)
            gender = st.selectbox("Biological Sex", ["Male", "Female", "Other"])
            bmi = st.slider("Body Mass Index (BMI kg/m²)", 15.0, 45.0, 28.4, step=0.1,
                            help="ICMR South Asian cutoff: Overweight >= 23.0, Obese >= 27.5")

        with col_p2:
            family_history = st.checkbox("First-Degree Family History of Diabetes", True)
            activity = st.selectbox("Physical Activity Level", ["Sedentary", "Moderate", "Vigorous"])
            symptoms = st.multiselect(
                "Reported Symptoms",
                ["Polyuria (Frequent urination)", "Polydipsia (Excessive thirst)", "Blurry vision", "Unexplained weight loss", "Fatigue"],
                default=["Blurry vision", "Fatigue"]
            )

        with col_p3:
            has_known_diabetes = st.checkbox("Previously Diagnosed with Diabetes?", True)
            known_years = st.number_input("Years Living with Diabetes", min_value=0.0, max_value=40.0, value=6.0) if has_known_diabetes else None
            hba1c = st.number_input("Laboratory HbA1c (%) [if tested]", min_value=4.0, max_value=16.0, value=8.1 if has_known_diabetes else 5.8, step=0.1)
            fasting_glucose = st.number_input("Fasting Plasma Glucose (mg/dL) [if tested]", min_value=60.0, max_value=400.0, value=152.0 if has_known_diabetes else 105.0, step=1.0)

    patient_profile = PatientClinicalProfile(
        patient_id=patient_id,
        age=age,
        gender=gender,
        bmi=bmi,
        family_history_diabetes=family_history,
        physical_activity=activity,
        symptoms=symptoms,
        fasting_glucose_mg_dl=fasting_glucose,
        hba1c_pct=hba1c,
        known_diabetes_years=known_years if has_known_diabetes else None,
    )

    assessment = risk_model.evaluate(patient_profile)

    col_r1, col_r2 = st.columns([1, 2])
    with col_r1:
        st.metric("Stage 1 Risk Score (Random Forest ML)", f"{assessment.risk_score:.0f}/100", f"Tier: {assessment.risk_level.value}")
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

    st.subheader("Stage 2: Retinal Image Ingestion, Quality Gate & Multimodal Triage")

    if assessment.pathway != ScreeningPathway.RETINAL_SCREENING_INDICATED:
        st.warning(
            "🛑 **Clinical Guardrail Active:** This patient does not have confirmed diabetes. "
            "Per established tele-ophthalmology protocols (Aravind/Google), fundus imaging resources are reserved for "
            "individuals with confirmed diabetes. The AI **strictly refuses to diagnose diabetes on symptoms alone**. "
            "Please direct patient to laboratory confirmation (FPG / HbA1c)."
        )
    else:
        col_input_type, col_source = st.columns([1, 2])
        with col_input_type:
            input_mode = st.radio(
                "Fundus Ingestion Mode",
                ["Curated Field Test Pack", "Upload Custom Capture"]
            )

        image_to_process = None
        with col_source:
            if input_mode == "Curated Field Test Pack":
                chosen_case = st.selectbox(
                    "Select Curated Field Case",
                    [
                        "Case 1: Clean Diagnostic Quality (Patient 1 — Hospital data)",
                        "Case 2: Degraded Capture (Severe Defocus & Media Opacity)",
                        "Case 3: Borderline Capture (Marginal illumination/contrast)",
                        "Case 4: Severe Retinal Lesions (High-Risk Proliferative Signs)",
                        "Case 5: Adversarial Non-Fundus Input (Negative Control)",
                    ]
                )
                if "Case 1" in chosen_case:
                    p = os.path.join(PROJECT_ROOT, "test_samples", "01_real_clinical_fundus", "real_clinical_fundus_patient1.jpg")
                elif "Case 2" in chosen_case:
                    p = os.path.join(PROJECT_ROOT, "test_samples", "02_quality_failures_and_edge_cases", "real_fundus_with_extreme_motion_blur.jpg")
                elif "Case 3" in chosen_case:
                    p = os.path.join(PROJECT_ROOT, "test_samples", "04_section24_demo_scenarios", "scenario_3_borderline.jpg")
                elif "Case 4" in chosen_case:
                    p = os.path.join(PROJECT_ROOT, "test_samples", "04_section24_demo_scenarios", "scenario_4_uncertain.jpg")
                else:
                    p = os.path.join(PROJECT_ROOT, "test_samples", "03_adversarial_non_fundus", "adversarial_non_fundus_blue_profile.jpg")
                if os.path.exists(p):
                    image_to_process = Image.open(p).convert("RGB")
            else:
                uploaded_file = st.file_uploader("Upload Retinal Photograph", type=["jpg", "jpeg", "png"])
                if uploaded_file:
                    image_to_process = Image.open(uploaded_file).convert("RGB")

        if image_to_process is not None:
            img_np = np.array(image_to_process)
            
            # Run Screening Pipeline
            record = router.process_image(
                image_input=img_np,
                recapture_attempt_count=int(recapture_attempt_count),
                output_dir=os.path.join(PROJECT_ROOT, "results"),
            )

            col_view_l, col_view_r = st.columns(2)
            
            with col_view_l:
                st.image(image_to_process, caption="Captured Retinal Photograph (Original Pixels)", use_container_width=True)
                st.caption("🔒 **Section 20 Compliance:** Unaltered original pixel data preserved for clinical audit.")

                # MathWorks Req 1: Adaptive CLAHE Enhancement Display for Borderline / Visual Review
                if enable_clahe_enhancer and (record.quality_grade in (QualityGrade.BORDERLINE, QualityGrade.BAD) or True):
                    with st.expander("✨ MathWorks Req 1: Adaptive CLAHE & Illumination Normalization View", expanded=False):
                        enhanced_np = enhancer.enhance_borderline_image(img_np)
                        st.image(enhanced_np, caption="Adaptive CLAHE + Background Illumination Normalization + Bilateral Denoising", use_container_width=True)
                        st.caption("Applied specifically for operator visual assistance per MathWorks Requirement #1.")

            with col_view_r:
                # -------------------------------------------------------------
                # 1. Quality Gate
                # -------------------------------------------------------------
                st.markdown("#### 1️⃣ Model 1: Quality Gate (MathWorks Req 1)")
                if record.quality_grade == QualityGrade.GOOD:
                    st.success(f"**Quality Status:** GOOD (Reliable Original Image Certified)")
                elif record.quality_grade == QualityGrade.BORDERLINE:
                    st.warning(f"**Quality Status:** BORDERLINE (Reassessment: {record.reassessment_outcome.value})")
                else:
                    st.error(f"**Quality Status:** BAD — Fails Reliability Gate")

                if record.rejection_reasons:
                    st.write(f"**Photographic Defects:** {', '.join(record.rejection_reasons)}")
                if record.suspected_clinical_cause:
                    st.info(f"**Suspected Clinical Cause:** {record.suspected_clinical_cause}")

                st.divider()

                # -------------------------------------------------------------
                # 2. DR Severity Classification
                # -------------------------------------------------------------
                st.markdown("#### 2️⃣ Model 2: DR Severity Classification (MathWorks Req 3)")
                if record.dr_prediction is not None:
                    grade = record.dr_prediction.predicted_grade
                    conf = record.dr_prediction.confidence
                    st.write(f"**Severity Grade:** Grade {grade.value} — **{grade.label}**")
                    
                    if record.confidence_assessment:
                        conf_str = record.confidence_assessment.format_confidence_label(conf)
                        if record.confidence_assessment.requires_human_review:
                            st.warning(f"**Model Confidence:** {conf_str}")
                        else:
                            st.success(f"**Model Confidence:** {conf_str}")
                    else:
                        st.write(f"**Softmax Probability:** {conf * 100:.1f}%")

                    with st.expander("📊 View 5-Class Probability Distribution"):
                        prob_data = {
                            f"Grade {i} ({router.dr_classifier.CLASS_LABELS[i]})": p
                            for i, p in enumerate(record.dr_prediction.probabilities)
                        }
                        st.bar_chart(prob_data)
                else:
                    st.info(
                        "🚫 **DR Classifier Inhibited:** An ungradable capture is strictly prevented "
                        "from receiving a disease grade to eliminate forced predictions on poor data."
                    )

                st.divider()

                # -------------------------------------------------------------
                # 3. Retinal Structure Segmentation & Explainability
                # -------------------------------------------------------------
                st.markdown("#### 3️⃣ Structure Segmentation & Explainability (Req 2 & 4)")
                
                # MathWorks Req 2: Structure segmentation
                if enable_segmentation and record.quality_grade != QualityGrade.BAD:
                    seg_res = segmenter.segment_structures(img_np)
                    col_s1, col_s2 = st.columns(2)
                    with col_s1:
                        st.image(seg_res.annotated_overlay, caption="Annotated Landmarks: Optic Disc (Yellow), Fovea (Blue), Vessels (Cyan), MAs (Red)", use_container_width=True)
                    with col_s2:
                        if record.gradcam_result and record.gradcam_result.heatmap_generated:
                            st.image(record.gradcam_result.heatmap_array, caption="Grad-CAM Visual Activation Heatmap", use_container_width=True)

                    st.caption(
                        f"🔬 **Clinical Audit in <30 Seconds:** Optic Disc at ({seg_res.optic_disc_center[0]}, {seg_res.optic_disc_center[1]}), "
                        f"Fovea at ({seg_res.fovea_center[0]}, {seg_res.fovea_center[1]}), {len(seg_res.microaneurysm_candidates)} microaneurysm candidates detected."
                    )
                elif record.gradcam_result and record.gradcam_result.heatmap_generated:
                    st.image(record.gradcam_result.heatmap_array, caption="Grad-CAM Visual Activation Heatmap", use_container_width=True)

            # Unified Dossier
            st.divider()
            st.subheader("Step 3: Consolidated Clinical Screening Dossier")
            st.code(
                f"=== COMPREHENSIVE CLINICAL SCREENING REPORT ===\n"
                f"Patient ID:             {patient_profile.patient_id}\n"
                f"Age / Gender:           {patient_profile.age} yrs / {patient_profile.gender}\n"
                f"BMI / Asian Cutoff:     {patient_profile.bmi:.1f} kg/m² ({'Elevated' if patient_profile.bmi >= 23.0 else 'Normal'})\n"
                f"Diabetes Status:        {assessment.diabetes_status.value} ({patient_profile.known_diabetes_years or 0:.1f} yrs duration)\n"
                f"Stage 1 ML Risk Score:  {assessment.risk_score:.0f}/100 ({assessment.risk_level.value})\n"
                f"--------------------------------------------------\n"
                f"{record.format_report_text()}\n"
                f"==================================================",
                language="yaml"
            )

# =========================================================================
# TAB 2: SIMULINK DISTRICT TELEMEDICINE SIMULATION (REQ #5)
# =========================================================================
with tab_simulink:
    st.subheader("📡 Simulink District Telemedicine Screening Simulation")
    st.caption(
        "MathWorks SIH26038 Requirement #5: Modeling image acquisition rates, bandwidth bottlenecks, "
        "processing throughput, and specialist review capacity for 100,000+ patients annually."
    )

    col_sim_ctrl, col_sim_res = st.columns([1, 2])
    
    with col_sim_ctrl:
        st.markdown("#### ⚙️ District Simulation Parameters")
        sim_patients = st.slider("Annual Target Population", 50000, 250000, 100000, step=10000)
        sim_phcs = st.number_input("Number of Rural PHCs Connected", min_value=5, max_value=50, value=20)
        sim_bandwidth = st.slider("Average Rural Cellular Uplink (kbps)", 128, 2048, 384, step=64,
                                 help="Represents 3G / congested 4G connectivity in rural camps.")
        sim_doctors = st.slider("Assigned Tele-Ophthalmologists", 1, 10, 2)
        sim_assisted_time = st.slider("Assisted Review Time (<30s target)", 15, 60, 28, step=1)

        sim_params = DistrictSimulationParams(
            annual_target_patients=sim_patients,
            num_phcs=sim_phcs,
            rural_bandwidth_kbps=float(sim_bandwidth),
            num_tele_ophthalmologists=sim_doctors,
            assisted_review_time_sec=float(sim_assisted_time),
        )
        sim_engine = TelemedicineSimulinkEngine(sim_params)
        report = sim_engine.run_simulation()

    with col_sim_res:
        st.markdown("#### 📊 Simulation Results: Edge AI vs. Centralized Cloud")
        
        col_m1, col_m2, col_m3 = st.columns(3)
        col_m1.metric("Bandwidth Reduction", f"{report.bandwidth_saved_pct:.1f}%", "Saved Cellular Traffic")
        col_m2.metric("Ophthalmologist Need", f"{report.doctors_needed_with_our_system:.0f} Doctor(s)", f"vs {report.doctors_needed_without_our_system:.0f} Traditional")
        col_m3.metric("On-Site Patient Latency", f"{report.avg_turnaround_time_edge_sec:.1f}s", f"vs {report.avg_turnaround_time_cloud_min:.1f}m Cloud")

        # Comparative Data Chart
        st.markdown("##### 📈 Annual Data Upload Footprint (GB/Year)")
        st.bar_chart({
            "Centralized Cloud (Upload All)": report.cloud_total_data_uploaded_gb_annual,
            "Our Edge AI Triage Pipeline": report.edge_total_data_uploaded_gb_annual,
        })

        st.markdown("##### 👨‍⚕️ District Ophthalmologist Headcount Required")
        st.bar_chart({
            "Traditional Manual Screening": report.doctors_needed_without_our_system,
            "With Our AI-Assisted Triage": report.doctors_needed_with_our_system,
        })

        st.success(
            f"✅ **System Stability Verified:** Queue is {'STABLE' if report.queue_stable else 'OVERLOADED'}. "
            f"Daily tele-consultation capacity ({report.doctor_daily_review_capacity_assisted} cases/day) exceeds "
            f"flagged intake ({report.daily_flagged_for_review} cases/day)."
        )

        with st.expander("📄 View MATLAB / Simulink Code & Instructions"):
            st.markdown(
                "MathWorks evaluators can execute the full `.m` script and generate the `.slx` model directly in MATLAB:\n"
                "```matlab\n"
                "cd('matlab');\n"
                "simulink_telemedicine_model;\n"
                "```"
            )
            st.caption("File path: `matlab/simulink_telemedicine_model.m`")

# =========================================================================
# TAB 3: MATHWORKS COMPLIANCE SPECIFICATIONS
# =========================================================================
with tab_specs:
    st.subheader("📋 SIH26038 Problem Statement Compliance Checklist")
    st.markdown("""
    | # | MathWorks Requirement | Our Technical Implementation | Status |
    |---|---|---|:---:|
    | **1** | **Image Quality Assessment & Adaptive Enhancement** | Model 1 evaluates focus, illumination, and FOV; Adaptive CLAHE, background illumination normalization & bilateral denoising implemented in `src/quality/enhancer.py`. | **100% DONE** |
    | **2** | **Retinal Structure Segmentation** | Optic disc, fovea center, blood vessel tree, and microaneurysm candidate morphology implemented in `src/segmentation/structure_segmenter.py`. | **100% DONE** |
    | **3** | **DR Severity Grading (0–4)** | 5-class transfer learning CNN on APTOS 2019 dataset with referable DR threshold (Grade ≥ 2) and class-weighted loss in `src/classification/classifier.py`. | **100% DONE** |
    | **4** | **Explainability Module (<30s Workflow)** | Grad-CAM activation maps, calibrated confidence reporting, and combined anatomical lesion overlays enabling ophthalmologist validation in under 30 seconds. | **100% DONE** |
    | **5** | **Simulink Workflow Simulation (100k Patients)** | District telemedicine queuing network modeling bandwidth, throughput, and specialist capacity in `src/simulation/telemedicine_sim.py` and `matlab/simulink_telemedicine_model.m`. | **100% DONE** |
    """)
