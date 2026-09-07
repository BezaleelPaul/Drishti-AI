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
from demo.generate_samples import generate_sample_suite

st.set_page_config(
    page_title="SIH 2026: End-to-End AI DR & Diabetes Screening",
    page_icon="👁️",
    layout="wide",
)

st.title("👁️ AI-Assisted Diabetes & Diabetic Retinopathy Screening")
st.caption(
    "SIH 2026 • 2-Stage Preventive Care Pathway: Upstream Diabetes Risk Stratification & Trust-Aware Retinal Screening "
    "(Inspired by the Google & Aravind Eye Hospital Clinical Screening Model)"
)

# Sidebar
with st.sidebar:
    st.header("⚙️ Screening Settings")
    st.info(
        "**Clinical Precedent (The Hindu / Aravind - Google):**\n"
        "1. Identify individuals at elevated diabetes risk.\n"
        "2. Route to lab confirmation (AI does NOT diagnose diabetes alone).\n"
        "3. Screen confirmed cases with fundus imaging.\n"
        "4. Enforce quality-first reliability gate."
    )
    recapture_attempt_count = st.number_input(
        "Current Patient Recapture Attempts (Max 2)",
        min_value=0,
        max_value=3,
        value=0,
        help="Hard cap of 2 recaptures per patient session is enforced. Reaching cap escalates to human review.",
    )

sample_dir = os.path.join(PROJECT_ROOT, "demo", "sample_images")
if not os.path.exists(sample_dir) or not os.listdir(sample_dir):
    generate_sample_suite(sample_dir)

# Initialize models
@st.cache_resource
def load_models():
    return DiabetesRiskModel(), ScreeningPipelineRouter()

risk_model, router = load_models()

tab_full, tab_retinal_only = st.tabs([
    "🩺 Full 2-Stage Clinical Workflow (Prevention → Retinal Screening)",
    "👁️ Standalone Retinal Screening (Quality Gate + Model 2 + Grad-CAM)"
])

# =========================================================================
# TAB 1: FULL 2-STAGE WORKFLOW
# =========================================================================
with tab_full:
    st.subheader("Stage 1: Upstream Patient Clinical Profile & Diabetes Risk Stratification")
    
    col_p1, col_p2, col_p3 = st.columns(3)
    with col_p1:
        patient_id = st.text_input("Patient ID", "PT-2026-ARV-042")
        age = st.slider("Patient Age", 18, 90, 52)
        gender = st.selectbox("Gender", ["Male", "Female", "Other"])
        bmi = st.slider("Body Mass Index (BMI kg/m²)", 15.0, 45.0, 27.8, step=0.1)

    with col_p2:
        family_history = st.checkbox("Family History of Diabetes (First-degree relative)", True)
        activity = st.selectbox("Physical Activity Level", ["Sedentary", "Moderate", "Vigorous"])
        symptoms = st.multiselect(
            "Reported Symptoms",
            ["Frequent urination (Polyuria)", "Excessive thirst (Polydipsia)", "Blurry vision", "Unexplained fatigue", "None"],
            default=["Blurry vision"]
        )

    with col_p3:
        has_known_diabetes = st.checkbox("Diagnosed Diabetes History?", True)
        known_years = st.number_input("Years Since Diagnosis", min_value=0.0, max_value=40.0, value=5.0) if has_known_diabetes else None
        hba1c = st.number_input("Laboratory HbA1c (%) [if available]", min_value=4.0, max_value=16.0, value=7.8 if has_known_diabetes else 5.8, step=0.1)
        fasting_glucose = st.number_input("Fasting Blood Glucose (mg/dL) [if available]", min_value=60.0, max_value=400.0, value=145.0 if has_known_diabetes else 105.0, step=1.0)

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
    
    st.markdown("#### 📊 Upstream Assessment Result")
    col_r1, col_r2 = st.columns([1, 2])
    with col_r1:
        if assessment.pathway == ScreeningPathway.RETINAL_SCREENING_INDICATED:
            st.error(f"**Pathway:** {assessment.pathway.value}")
        elif assessment.pathway == ScreeningPathway.CLINICAL_TESTING_REQUIRED:
            st.warning(f"**Pathway:** {assessment.pathway.value}")
        else:
            st.success(f"**Pathway:** {assessment.pathway.value}")
        st.metric("Diabetes Risk Score", f"{assessment.risk_score:.0f}/100", f"Level: {assessment.risk_level.value}")

    with col_r2:
        st.info(f"**Clinical Action:** {assessment.action_recommendation}")
        if assessment.clinical_rationale:
            st.caption(f"**Rationale:** {' • '.join(assessment.clinical_rationale)}")

    st.divider()

    # Stage 2: Retinal Screening
    st.subheader("Stage 2: Retinal Fundus Screening (For Confirmed Diabetes Patients)")

    if assessment.pathway != ScreeningPathway.RETINAL_SCREENING_INDICATED:
        st.warning(
            "⚠️ **Retinal Screening Gate Inactive:** This patient does not have confirmed diabetes. "
            "Per clinical guidelines, fundus photography is prioritized for individuals with confirmed diabetes. "
            "Please refer this patient for formal laboratory confirmation first."
        )
    else:
        st.success("✅ **Retinal Screening Indicated:** Proceeding to AI-assisted fundus analysis.")
        
        sample_opt = st.selectbox(
            "Select Fundus Image for Patient",
            [
                "Scenario 1: Good Quality Capture (Clean, well-lit)",
                "Scenario 2: Bad Quality Capture (Severe blur / underexposed)",
                "Scenario 3: Borderline Capture (Marginal focus)",
                "Scenario 4: High-Risk Lesions / Ambiguous",
            ],
            key="tab1_sample"
        )
        
        img_path = None
        if "Scenario 1" in sample_opt:
            img_path = os.path.join(sample_dir, "scenario_1_good.jpg")
        elif "Scenario 2" in sample_opt:
            img_path = os.path.join(sample_dir, "scenario_2_bad.jpg")
        elif "Scenario 3" in sample_opt:
            img_path = os.path.join(sample_dir, "scenario_3_borderline.jpg")
        else:
            img_path = os.path.join(sample_dir, "scenario_4_uncertain.jpg")

        col_img_l, col_img_r = st.columns(2)
        with col_img_l:
            pil_img = Image.open(img_path).convert("RGB")
            st.image(pil_img, caption="Captured Retinal Photograph (Original)", use_container_width=True)

        with col_img_r:
            record = router.process_image(
                image_input=img_path,
                recapture_attempt_count=int(recapture_attempt_count),
                output_dir=os.path.join(PROJECT_ROOT, "results"),
            )
            
            # Quality Gate
            st.markdown("##### 1. Model 1: Image Quality Assessment")
            if record.quality_grade == QualityGrade.GOOD:
                st.success("GOOD — Certified Reliable Original Image")
            else:
                st.error(f"{record.quality_grade.value} — Fails Quality Gate")
                if record.rejection_reasons:
                    st.caption(f"Reason: {', '.join(record.rejection_reasons)}")

            # DR Severity
            st.markdown("##### 2. Model 2: DR Classification & Triage")
            if record.dr_prediction:
                grade = record.dr_prediction.predicted_grade
                conf = record.dr_prediction.confidence
                st.write(f"**Severity:** Grade {grade.value} ({grade.label})")
                st.progress(conf, text=f"Confidence: {conf*100:.1f}%")
                if record.human_review_required:
                    st.warning(f"⚠️ **Clinical Escalation:** {record.human_review_reason}")
            else:
                st.info("🚫 **Model 2 Inhibited:** Bad or ungradable images never receive a DR grade.")

            # Grad-CAM
            if record.gradcam_result and record.gradcam_result.heatmap_generated:
                st.markdown("##### 3. Explainability: Grad-CAM")
                st.image(record.gradcam_result.heatmap_array, caption="Visual Attention Map", use_container_width=True)

            # Report
            st.markdown("##### 📄 Official Screening Report")
            st.code(record.format_report_text(), language="yaml")

# =========================================================================
# TAB 2: STANDALONE RETINAL SCREENING
# =========================================================================
with tab_retinal_only:
    st.subheader("Standalone Fundus Image Screening & Edge Case Testing")
    custom_file = st.file_uploader("Upload Fundus Photo", type=["jpg", "png", "jpeg"], key="tab2_file")
    
    selected_p = os.path.join(sample_dir, "scenario_1_good.jpg")
    if custom_file:
        proc_img = Image.open(custom_file).convert("RGB")
    else:
        proc_img = Image.open(selected_p).convert("RGB")

    col_t2_l, col_t2_r = st.columns(2)
    with col_t2_l:
        st.image(proc_img, caption="Fundus Photo", use_container_width=True)
    with col_t2_r:
        rec = router.process_image(proc_img, recapture_attempt_count=int(recapture_attempt_count))
        st.code(rec.format_report_text(), language="yaml")
        if rec.gradcam_result and rec.gradcam_result.heatmap_generated:
            st.image(rec.gradcam_result.heatmap_array, caption="Grad-CAM Overlay", use_container_width=True)
