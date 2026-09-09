# SIH 2026 3-Minute Video Demonstration Script
## System: Drishti-AI — Streamlit Live Dashboard (`http://localhost:8501`)

---

### Segment 1: Introduction & Problem Context (0:00 – 0:35)
- **Visual on Screen:** Title slide or Dashboard header showing *Drishti-AI: Explainable Dual-Stage DR Screening*.
- **Voiceover:**
  > *"Diabetic retinopathy affects nearly 14 million people in India, but mass screening in rural areas fails due to variable image quality from low-cost fundus cameras and the 'black-box' nature of deep learning. Here is Drishti-AI, our explainable screening pipeline built for MathWorks problem statement SIH26038."*

---

### Segment 2: Stage 1 Community Triage & Quality Gate Rejection (0:35 – 1:20)
- **Visual on Screen:** Click Tab 1 (*"Clinical Screening Pipeline"*).
  1. Scroll down to **Stage 1: Upstream Diabetes Risk Assessment**.
  2. Show the risk calculator: Age 52, BMI 27.5 (ICMR Asian-Indian overweight), Symptoms present, FPG unknown $\rightarrow$ Click *"Evaluate Risk"*.
  3. Show the result badge: **"CLINICAL TESTING REQUIRED"** (directs to Fasting Plasma Glucose / HbA1c test).
- **Voiceover:**
  > *"First, our upstream clinical engine verifies risk factors before costly imaging. If diabetes is unconfirmed, patients are routed to laboratory tests, preventing false screening."*
- **Visual on Screen:**
  4. Now select a confirmed diabetic patient.
  5. Under **Stage 2: Retinal Image Ingestion**, choose Scenario 2: *"Degraded Fundus Photo (Blurry / Underexposed)"*.
  6. Click *"Run Complete Screening Pipeline"*.
  7. Point cursor to the red alert banner: **"QUALITY STATUS: UNRELIABLE (BAD)"**.
  8. Point out: **DR Severity Grade: "NOT GENERATED (MODEL 2 SUPPRESSED)"**.
  9. Show the detected defects: *"Severe blur / loss of retinal focus"* and *"Suspected media opacity/cataract"*.
- **Voiceover:**
  > *"When an operator takes a blurry photo, standard AI systems dangerously guess a grade. In Drishti-AI, the Model 1 Quality Gate strictly suppresses the DR classifier, flags the suspected biological cause—like cataract or small pupil—and prompts for immediate guided recapture. Zero diagnostic leakage."*

---

### Segment 3: High-Quality Grading & Grad-CAM Explainability (1:20 – 2:05)
- **Visual on Screen:**
  1. Switch to Scenario 1: *"Clean Retinal Fundus Photo"*.
  2. Click *"Run Complete Screening Pipeline"*.
  3. Green badge appears: **"IMAGE QUALITY: GOOD (RELIABLE)"**.
  4. Anatomical segmentation is displayed: Optic Disc, Fovea, and Retinal Vessel Tree clearly localized.
  5. DR Classification displays: **"Grade 2 — Moderate Non-Proliferative DR"**.
  6. Point out the confidence card: *"Model Confidence: 38.9% — Low confidence; human review recommended"*.
  7. Show the Grad-CAM visual heatmap overlay highlighting retinal lesions.
- **Voiceover:**
  > *"On a gradable image, Model 1 applies adaptive CLAHE without altering diagnostic morphology. Our segmentation engine localizes the Optic Disc, Fovea, and vascular tree. EfficientNetB0 grades the retina, and Grad-CAM visualizes the exact microaneurysms and hemorrhages in under 1.2 seconds. Rather than claiming 99% accuracy, our calibrated margin flags low confidence for human specialist review."*

---

### Segment 4: District-Scale Simulink Telemedicine Simulation (2:05 – 2:45)
- **Visual on Screen:** Click Tab 2 (*"Simulink 100k Patient Simulation"*).
  1. Display the district architecture parameters: 100,000 patients/year, 50 rural PHCs, 1 District Hospital.
  2. Show the simulation output graphs:
     - Bandwidth comparison: Raw DICOM (250 GB) vs. Edge AI Filtered (3.4 GB) $\rightarrow$ **98.6% Bandwidth Saving**.
     - Queuing latency: Under 18 seconds per patient at the PHC.
     - Doctor workload: 100,000 cases reduced to ~15,200 referral cases.
- **Voiceover:**
  > *"For MathWorks Requirement 5, we simulated 100,000 patients across 50 rural PHCs using discrete-event queuing theory in MATLAB and Simulink. Edge AI filtering cuts network bandwidth by 98.6%, allowing remote PHCs on 2G/3G connections to function smoothly and reducing ophthalmologist burden to manageable levels."*

---

### Segment 5: Compliance Matrix & Conclusion (2:45 – 3:00)
- **Visual on Screen:** Click Tab 3 (*"MathWorks SIH26038 Compliance"*).
  - Quick scroll showing 100% green checkmarks across all 5 MathWorks technical requirements.
- **Voiceover:**
  > *"Drishti-AI is offline-ready, hardware-agnostic, and medically safe. Thank you!"*
