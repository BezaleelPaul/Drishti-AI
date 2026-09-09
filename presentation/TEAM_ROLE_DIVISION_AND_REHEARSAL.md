# SIH 2026 Team Role Division & Live Pitch Script
## Problem Statement SIH26038 (MathWorks): Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## 1. Team Composition & Strategic Division of Responsibilities

| Member | Role | Core Domain & Modules Owned |
| :--- | :--- | :--- |
| **Bezaleel** | **Team Lead & Full-Stack Architect** | System Architecture, Quality Gate Orchestration, Bounded Recapture Logic, Streamlit UI Integration (`src/pipeline/router.py`, `demo/app.py`). |
| **Madhu** | **Clinical Intelligence & Biological Triage Lead** | Stage 1 Clinical Risk Engine, ICMR Asian-Indian cutoffs, Biological defect attribution (cataract vs. mydriasis), Retinal Anatomical Segmentation (`src/clinical_risk/`, `src/segmentation/`). |
| **Akshay** | **Deep Learning & MathWorks Modeling Lead** | EfficientNetB0 5-class severity grading, Grad-CAM explainability (<30s constraint), MATLAB Simulink 100,000-patient discrete-event simulation (`src/classification/`, `matlab/simulink_telemedicine_model.m`). |
| **Adithya** | **Validation, Edge Cases & Telemedicine Ops Lead** | 150-sample A/B experiment evaluation, Adversarial & non-fundus edge cases, 98.6% bandwidth optimization, Rural PHC field operations (`tests/`, `evaluate_ab_test.py`, `docs/AB_EXPERIMENT_RESULTS.md`). |

---

## 2. Live Pitch Presentation Script (8-Minute Demonstration Flow)

### Part 1: Introduction & Clinical Need (Minutes 0:00 – 1:30) — Speaker: Bezaleel
- *"Respected judges, India has over 77 million diabetic adults, and diabetic retinopathy is a leading cause of preventable blindness. Early detection saves 90% of vision, yet rural India has only one ophthalmologist for every 100,000 citizens."*
- *"Most existing AI solutions act as black boxes and suffer from a catastrophic flaw: when fed blurry, poor-quality field images, they still force a diagnosis, generating high false positives and false negatives."*
- *"To solve this, our team has built Drishti-AI: an explainable, dual-stage, clinically-gated screening and district telemedicine pipeline compliant with all MathWorks SIH26038 requirements."*

---

### Part 2: Upstream Clinical Risk & Anatomical Structure Segmentation (Minutes 1:30 – 3:30) — Speaker: Madhu
*(Highlighting Madhu's Biology + Engineering background)*
- *"Coming from a biological and biomedical engineering background, we realized that an eye photograph alone should never be the sole gateway. Following the clinical protocols of Google and Aravind Eye Hospital, we introduced an Upstream Clinical Risk Engine."*
- *"We screen patients on age, ICMR Asian-Indian BMI cutoffs, family history, and symptoms. Crucially, before taking an eye photo, high-risk community members are gated to laboratory testing (HbA1c and Fasting Plasma Glucose) for physician confirmation."*
- *"For patients entering retinal triage, our Model 1 evaluates photographic validity. If an image is degraded, our system doesn't just throw an error—it identifies the biological cause: whether it is media opacity from a cataract or an un-dilated pupil requiring dark-room adaptation."*
- *"Furthermore, compliant with MathWorks Requirement 2, we extract the anatomical landmarks: the Optic Disc, Fovea center, retinal vascular tree, and microaneurysm candidates, ensuring the AI attends to physiologically real retinal anatomy."*

---

### Part 3: Deep Learning Grading, Explainability & Simulink Modeling (Minutes 3:30 – 5:30) — Speaker: Akshay
- *"For reliable images, our Model 2 employs an EfficientNetB0 architecture trained on 5 severity grades: No DR, Mild, Moderate, Severe, and Proliferative DR."*
- *"Addressing MathWorks Requirement 4, explainability is generated in under 1.2 seconds—well within the 30-second constraint—using Grad-CAM. Clinicians can immediately visualize the exact retinal lesions driving the prediction."*
- *"Crucially, we do not present raw overconfident numbers. Predictions with confidence under 60% or narrow class margins are automatically flagged with the disclaimer: 'Low confidence; specialist review recommended'."*
- *"For MathWorks Requirement 5, we built a comprehensive discrete-event queuing simulation in MATLAB and Simulink modeling a full district network of 100,000 patients across 50 rural PHCs and 1 District Hospital. The model proves that edge AI filtering slashes network bandwidth by 98.6% and reduces specialist workload from 100,000 down to 15,200 actionable cases."*

---

### Part 4: Live Demonstration & Safety Verification (Minutes 5:30 – 7:00) — Speaker: Bezaleel & Adithya
- **Bezaleel:** *(Shares screen with Streamlit UI)* *"Let's see this live in our offline-ready interface running on `localhost:8501`."*
  - Scenario 1: Clean Fundus photo $\rightarrow$ Passes Quality Gate $\rightarrow$ Grade 2 Moderate NPDR $\rightarrow$ Grad-CAM overlay displayed $\rightarrow$ Low confidence flagged honestly.
  - Scenario 2: Blurry / Defocused capture $\rightarrow$ Instantly rejected by Model 1 Quality Gate $\rightarrow$ Model 2 DR grade is strictly SUPPRESSED $\rightarrow$ Guided recapture prompt shown.
- **Adithya:** *"To prove clinical safety, we conducted an A/B/C experiment on 150 benchmark images. Standard classifiers forced a diagnosis on 100% of ungradable images. Our architecture achieved a 0% forced prediction rate, completely eliminating diagnostic leakage. Furthermore, our bounded recapture policy caps retries at 2 attempts before escalating to a human clinician."*

---

### Part 5: Impact & Conclusion (Minutes 7:00 – 8:00) — Speaker: Bezaleel
- *"Drishti-AI is hardware-agnostic, running on affordable handheld fundus cameras and low-cost laptops entirely offline. By combining upstream clinical risk, non-negotiable quality triage, explainable grading, and district-scale tele-ophthalmology modeling, we deliver a clinically trustworthy solution ready for rural India."*
- *"We welcome your questions. Thank you!"*
