import os
import sys
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

st.set_page_config(
    page_title="AI-Assisted Diabetes & DR Screening Platform",
    page_icon="👁️",
    layout="wide",
)

st.title("👁️ Integrated Diabetes Risk & Diabetic Retinopathy Screening")
st.caption(
    "Clinical Decision Support Platform — Inspired by the Aravind Eye Hospital & Google Tele-Ophthalmology Workflow "
    "(SIH 2026 Professional Architecture)"
)

# -------------------------------------------------------------------------
# Sidebar Controls
# -------------------------------------------------------------------------
with st.sidebar:
    st.header("⚙️ Clinical Protocol Settings")
    st.markdown(
        "**Clinical Safeguards:**\n"
        "1. **Upstream First:** Risk assessment before retinal imaging.\n"
        "2. **No Autonomous Diagnosis:** Symptoms alone cannot diagnose diabetes.\n"
        "3. **Quality Gate:** Unusable images never receive a DR grade.\n"
        "4. **Human Safety Layer:** Low confidence & high-risk grades trigger specialist review."
    )

    st.divider()
    st.subheader("Field Operational Controls")
    
    # Recapture attempt tracking
    recapture_attempt_count = st.number_input(
        "Patient Recapture Attempts (Max 2)",
        min_value=0,
        max_value=3,
        value=0,
        help="Enforces hard cap of 2 recaptures per patient session. Reaching cap escalates to human review.",
    )

    # Threshold calibration mode
    threshold_profile = st.selectbox(
        "Quality Gate Operating Point",
        ["Balanced (Standard PHC Setting)", "Permissive (Specialist Clinic Over-Read)", "Conservative (Autonomous Screening)"],
        help="Adjusts Model 1 strictness. Permissive mode allows borderline captures with visible pathology to be graded under clinical supervision."
    )

# Cache models
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
    return risk_model, router

risk_model, router = get_screening_engine(threshold_profile)
sample_dir = os.path.join(PROJECT_ROOT, "test_samples")

# =========================================================================
# STEP 1: PATIENT INTAKE & UPSTREAM DIABETES RISK STRATIFICATION
# =========================================================================
st.subheader("Step 1: Upstream Patient Profile & Diabetes Risk Stratification")
st.caption("Zero-hardware community triage: Identifies individuals at metabolic risk before engaging retinal cameras.")

with st.expander("📋 Enter Patient Clinical Parameters", expanded=True):
    col_p1, col_p2, col_p3 = st.columns(3)
    with col_p1:
        patient_id = st.text_input("Patient ID", "ARV-2026-0842")
        age = st.slider("Patient Age", 18, 90, 52)
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

# Upstream Risk Card
col_r1, col_r2 = st.columns([1, 2])
with col_r1:
    st.metric("Upstream Risk Score (Random Forest ML)", f"{assessment.risk_score:.0f}/100", f"Tier: {assessment.risk_level.value}")
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

# =========================================================================
# STEP 2: CLINICAL CONFIRMATION GATE & RETINAL SCREENING
# =========================================================================
st.subheader("Step 2: Retinal Fundus Screening & Quality-First Triage")

if assessment.pathway != ScreeningPathway.RETINAL_SCREENING_INDICATED:
    st.warning(
        "🛑 **Clinical Guardrail Active:** This patient does not have confirmed diabetes. "
        "Per established tele-ophthalmology protocols (Aravind/Google), fundus imaging resources are reserved for "
        "individuals with confirmed diabetes. The AI **strictly refuses to diagnose diabetes on symptoms alone**. "
        "Please direct patient to laboratory confirmation (FPG / HbA1c)."
    )
else:
    # Retinal Screening is active!
    col_input_type, col_source = st.columns([1, 2])
    with col_input_type:
        input_mode = st.radio(
            "Fundus Ingestion Mode",
            ["Preset Test Pack (Section 24)", "Simulate Live Camera Upload"]
        )

    image_to_process = None
    with col_source:
        if input_mode == "Preset Test Pack (Section 24)":
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
        col_view_l, col_view_r = st.columns(2)
        
        with col_view_l:
            st.image(image_to_process, caption="Captured Retinal Photograph (Original Unmodified Pixels)", use_container_width=True)
            st.caption("🔒 **Section 20 Compliance:** No runtime pixel enhancement or contrast stretching applied.")

        with col_view_r:
            record = router.process_image(
                image_input=image_to_process,
                recapture_attempt_count=int(recapture_attempt_count),
                output_dir=os.path.join(PROJECT_ROOT, "results"),
            )

            # -------------------------------------------------------------
            # Quality Gate Section
            # -------------------------------------------------------------
            st.markdown("#### 1️⃣ Model 1: Image Quality Assessment Gate")
            if record.quality_grade == QualityGrade.GOOD:
                st.success(f"**Quality Status:** GOOD (Reliable Original Image Certified)")
            elif record.quality_grade == QualityGrade.BORDERLINE:
                st.warning(f"**Quality Status:** BORDERLINE (Reassessment: {record.reassessment_outcome.value})")
            else:
                st.error(f"**Quality Status:** BAD — Fails Reliability Gate")

            if record.rejection_reasons:
                st.write(f"**Identified Photographic Defects:** {', '.join(record.rejection_reasons)}")
            if record.suspected_clinical_cause:
                st.info(f"**Suspected Clinical/Biological Cause:** {record.suspected_clinical_cause}")

            st.divider()

            # -------------------------------------------------------------
            # DR Classification Section
            # -------------------------------------------------------------
            st.markdown("#### 2️⃣ Model 2: DR Severity Classification")
            if record.dr_prediction is not None:
                grade = record.dr_prediction.predicted_grade
                conf = record.dr_prediction.confidence
                st.write(f"**Severity Grade:** Grade {grade.value} — **{grade.label}**")
                
                # Medically calibrated confidence display
                if record.confidence_assessment:
                    conf_str = record.confidence_assessment.format_confidence_label(conf)
                    if record.confidence_assessment.requires_human_review:
                        st.warning(f"**Model Confidence:** {conf_str}")
                    else:
                        st.success(f"**Model Confidence:** {conf_str}")
                else:
                    st.write(f"**Softmax Probability:** {conf * 100:.1f}%")

                st.caption(
                    "ℹ️ *Note: Softmax output probabilities reflect raw neural-network activation. "
                    "Predictions below 60% or with class margin < 0.15 are flagged for human clinician review.*"
                )

                # Probabilities breakdown
                with st.expander("📊 View 5-Class Probability Distribution"):
                    prob_data = {
                        f"Grade {i} ({router.dr_classifier.CLASS_LABELS[i]})": p
                        for i, p in enumerate(record.dr_prediction.probabilities)
                    }
                    st.bar_chart(prob_data)
            else:
                st.info(
                    "🚫 **DR Classifier Inhibited:** An ungradable or rejected capture is strictly prevented "
                    "from receiving a disease grade to eliminate forced predictions on poor data."
                )

            st.divider()

            # -------------------------------------------------------------
            # Explainability Section
            # -------------------------------------------------------------
            if record.gradcam_result and record.gradcam_result.heatmap_generated:
                st.markdown("#### 3️⃣ Model Interpretability: Grad-CAM")
                st.image(
                    record.gradcam_result.heatmap_array,
                    caption=record.gradcam_result.description,
                    use_container_width=True
                )
                st.caption(f"🔬 *{record.gradcam_result.disclaimer}*")

# =========================================================================
# STEP 3: UNIFIED CLINICAL SCREENING DOSSIER
# =========================================================================
st.divider()
st.subheader("Step 3: Consolidated Clinical Screening Dossier")
st.caption("Complete, unified audit record integrating metabolic risk factors, retinal quality metrics, and ophthalmic referral recommendations.")

if assessment.pathway == ScreeningPathway.RETINAL_SCREENING_INDICATED and image_to_process is not None:
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
else:
    st.info("Complete patient intake to generate unified screening dossier.")
