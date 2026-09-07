import os
import sys
from PIL import Image
import streamlit as st

# Ensure repository root is in sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.pipeline.router import ScreeningPipelineRouter
from src.pipeline.schema import (
    HumanReviewType,
    QualityGrade,
    ReassessmentOutcome,
)
from demo.generate_samples import generate_sample_suite

st.set_page_config(
    page_title="SIH 2026: AI-Assisted DR Screening",
    page_icon="👁️",
    layout="wide",
)

# Custom header styling
st.title("👁️ AI-Assisted Diabetic Retinopathy Screening")
st.caption(
    "SIH 2026 Software Prototype Track — Final Professional Architecture (Locked to Approved Decision Flow)"
)

# Sidebar settings & info
with st.sidebar:
    st.header("⚙️ Pipeline Controls")
    st.info(
        "**Core Rule:** An ungradable image must NEVER receive a DR grade. "
        "Image reliability is evaluated first before any disease model is touched."
    )

    recapture_attempt_count = st.number_input(
        "Current Patient Recapture Attempts (Max 2)",
        min_value=0,
        max_value=3,
        value=0,
        help="Hard cap of 2 recaptures per patient session is enforced. Reaching cap escalates to human review.",
    )

    mode = st.radio(
        "Select Image Source",
        ["Preset Demo Scenarios (Section 24)", "Upload Custom Retinal Fundus Photo"],
    )

sample_dir = os.path.join(PROJECT_ROOT, "demo", "sample_images")
if not os.path.exists(sample_dir) or not os.listdir(sample_dir):
    generate_sample_suite(sample_dir)

selected_image_path = None
uploaded_file = None

if mode == "Preset Demo Scenarios (Section 24)":
    scenario = st.selectbox(
        "Choose Demo Scenario",
        [
            "Scenario 1: Good Image (Clean, well-lit -> passes gate -> grades DR -> Grad-CAM)",
            "Scenario 2: Bad Image (Severely blurred / dark -> fails gate -> immediate recapture)",
            "Scenario 3: Borderline Image (Marginal focus -> enters reassessment -> safe routing)",
            "Scenario 4: Uncertain / High-Risk (Passes gate -> flags low-confidence or severe grade for human review)",
        ],
    )
    if "Scenario 1" in scenario:
        selected_image_path = os.path.join(sample_dir, "scenario_1_good.jpg")
    elif "Scenario 2" in scenario:
        selected_image_path = os.path.join(sample_dir, "scenario_2_bad.jpg")
    elif "Scenario 3" in scenario:
        selected_image_path = os.path.join(sample_dir, "scenario_3_borderline.jpg")
    else:
        selected_image_path = os.path.join(sample_dir, "scenario_4_uncertain.jpg")
else:
    uploaded_file = st.file_uploader(
        "Upload Retinal Fundus Photograph (JPG/PNG)", type=["jpg", "jpeg", "png"]
    )

# Instantiate router
@st.cache_resource
def get_pipeline_router():
    return ScreeningPipelineRouter()

router = get_pipeline_router()

col_left, col_right = st.columns([1, 1])

image_to_process = None
if uploaded_file is not None:
    image_to_process = Image.open(uploaded_file).convert("RGB")
elif selected_image_path and os.path.exists(selected_image_path):
    image_to_process = Image.open(selected_image_path).convert("RGB")

with col_left:
    st.subheader("📷 Captured Retinal Image (Node 1)")
    if image_to_process is not None:
        st.image(image_to_process, caption="Original Unmodified Clinical Image", use_container_width=True)
        st.caption(
            "🔒 **Section 20 Compliance:** No pixel enhancement, CLAHE, or contrast "
            "stretching is applied to original pixels at runtime."
        )
    else:
        st.info("Please select or upload an image to begin screening.")

with col_right:
    st.subheader("📋 Screening Decision Flow & Results")
    if image_to_process is not None:
        with st.spinner("Executing decision flow (Node 2 to 11)..."):
            record = router.process_image(
                image_to_process,
                recapture_attempt_count=int(recapture_attempt_count),
                output_dir=os.path.join(PROJECT_ROOT, "results"),
            )

        # 1. Quality gate status (Model 1)
        st.markdown("### 1️⃣ Model 1: Image Quality Assessment (Node 2)")
        if record.quality_grade == QualityGrade.GOOD:
            st.success(f"**Status:** {record.quality_grade.value} — Reliable Original Image Certified")
        elif record.quality_grade == QualityGrade.BORDERLINE:
            st.warning(f"**Status:** BORDERLINE (Reassessment: {record.reassessment_outcome.value})")
        else:
            st.error(f"**Status:** BAD — Fails Quality Reliability Gate")

        if record.rejection_reasons:
            st.write(f"**Identified Issues:** {', '.join(record.rejection_reasons)}")

        # 2. DR Classification (Model 2)
        st.markdown("### 2️⃣ Model 2: DR Severity Classification (Node 7)")
        if record.dr_prediction is not None:
            grade = record.dr_prediction.predicted_grade
            conf = record.dr_prediction.confidence
            st.write(f"**Predicted Severity:** Grade {grade.value} — **{grade.label}**")
            st.progress(conf, text=f"Top-1 Softmax Confidence: {conf * 100:.1f}%")
            
            # Probability distribution bar chart
            prob_dict = {
                f"Grade {i} ({router.dr_classifier.CLASS_LABELS[i]})": p
                for i, p in enumerate(record.dr_prediction.probabilities)
            }
            st.bar_chart(prob_dict)

            # Confidence assessment
            if record.confidence_assessment and record.confidence_assessment.requires_human_review:
                st.warning(f"⚠️ **Clinical Review Triggered:** {' | '.join(record.confidence_assessment.flags)}")
        else:
            st.info("🚫 **Model 2 execution inhibited:** Bad or unverified images are strictly prohibited from DR grading.")

        # 3. Explainability (Grad-CAM)
        if record.gradcam_result and record.gradcam_result.heatmap_generated:
            st.markdown("### 3️⃣ Explainability: Grad-CAM (Node 9)")
            st.image(
                record.gradcam_result.heatmap_array,
                caption="Grad-CAM Visual Attention Overlay on Original Image",
                use_container_width=True,
            )
            st.caption(f"ℹ️ *{record.gradcam_result.disclaimer}*")

        # 4. Official Screening Report
        st.markdown("### 📄 Official Screening Report (Node 10 Format)")
        st.code(record.format_report_text(), language="yaml")

        # 5. Terminal Human Review routing
        if record.human_review_required:
            st.markdown("### 🚨 Terminal Safety: Human Review (Node 11)")
            if record.human_review_type == HumanReviewType.OPERATOR_LEVEL:
                st.error(
                    f"**Operator-Level Escalation:** {record.human_review_reason}\n\n"
                    "Action for field staff: Inspect ocular media, reposition camera, or arrange in-person specialist referral."
                )
            elif record.human_review_type == HumanReviewType.CLINICAL_LEVEL:
                st.warning(
                    f"**Clinical-Level Escalation:** {record.human_review_reason}\n\n"
                    "Action for ophthalmologist: Confirm/override grade and determine urgent treatment referral pathway."
                )
