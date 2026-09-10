# Smart India Hackathon 2026 — Official Presentation Deck
## Problem Statement ID: SIH26038 (MathWorks)
## Title: Explainable AI for Diabetic Retinopathy Screening in Rural India

---

### Slide 1: Title & Team Overview
- **Project Title:** Drishti-AI: Explainable Dual-Stage Diabetic Retinopathy Screening & District Tele-Ophthalmology Telemedicine Pipeline
- **Problem Statement ID:** SIH26038 | **Organization:** MathWorks
- **Theme:** MedTech / BioTech / HealthTech
- **Team Members:**
  - **Bezaleel:** Team Lead, Full-Stack Architecture, Quality Gate & Safety Router
  - **Madhu:** Clinical Risk Engine, Biological Defect Attribution & Retinal Structure Segmentation
  - **Akshay:** Deep Learning Classifier (EfficientNetB0), Grad-CAM Explainability & MATLAB Simulink Model
  - **Adithya:** Telemedicine Operations, A/B Testing Validation & Edge-Case Guardrails
  - **Sinduri:** Lead UI/UX Designer — ASHA Mobile Workflow, Field Design System & Figma Kits
  - **Megha:** Lead UI/UX Designer — Doctor Diagnostic Console, Clinical Data Visualization & ABDM Layouts

---

### Slide 2: The Clinical Reality & Problem Definition
- **Context in Rural India:**
  - Over **77 million diabetic adults** in India; ~18% develop Diabetic Retinopathy (DR).
  - DR causes preventable blindness if undetected; early triage saves 90% of sight.
  - **Extreme Ophthalmologist Deficit:** Only 1 ophthalmologist per 100,000 rural citizens.
- **Why Existing Centralized Models (e.g., Google Health ARDA) Fail in Rural India:**
  - **Hospital-Lab Bias:** Proven on curated hospital tabletop cameras with cloud GPUs; fails in field camps with cheap handheld cameras (Remidio, Forus 3Nethra) operated by ASHA workers.
  - **The Ungradable Image Blindspot:** Standard classifiers blindly assign DR grades to blurry or ungradable photos (leading to fatal false-negative risk).
  - **Cloud Dependency & Bandwidth Chokepoints:** Requires 5-15MB image uploads over unstable rural 2G/3G networks.
- **Our Real Innovation:** We do not claim to reinvent basic classification — we bridge the last mile by **making proven AI clinically deployable and accessible for everyone in rural India**.

---

### Slide 3: Proposed Solution — Dual-Stage Clinically-Gated Architecture
- **Philosophy:** Operationalizing deep learning at the rural edge with 100% offline execution (<180 ms on a ₹15k laptop).
- **Stage 1 (Upstream Community Health Worker Gate):**
  - Clinical risk factors (Age, ICMR Asian-Indian BMI cutoffs, Family History, Symptoms).
  - Fasting Plasma Glucose / HbA1c verification gate: directs at-risk patients to laboratory tests before unnecessary eye imaging.
- **Stage 2 (Retinal Image Screening Gate):**
  - **Model 1 (Quality Gate):** Native deep ensemble (`fundus_image_toolbox`) + dynamic contour circular ROI + multi-scale feature fusion ($S_{\text{blur}}, S_{\text{illum}}, S_{\text{contrast}}, S_{\text{fov}}$) + biological defect attribution.
  - **Adaptive CLAHE:** Contrast-limited adaptive histogram equalization in CIELAB space with dynamic contrast adaptation without altering diagnostic morphology.
  - **Model 2 (DR Classifier):** 5-class severity grading (Grades 0–4) via fine-tuned EfficientNetB0 (`final_model.keras`).
  - **Grad-CAM++ Explainability (<30s):** True gradient backpropagation with higher-order partial derivatives isolating dispersed micro-lesions.
  - **Safety Confidence Calibration:** Softmax margins (<60% flagged for specialist review).

---

### Slide 4: Anatomical Structure Localization & Quality Pipeline (MathWorks Req 1 & 2)
- **Quality Triaging (Model 1):**
  - Evaluates: Deep ensemble gradability index, multi-scale focus gradients, illumination uniformity, vessel-to-background contrast, and dynamic circular ROI coverage.
  - **Biological Defect Attribution:** Distinguishes between operator error (camera defocus/motion) vs. patient pathology (cataract media opacity, small un-dilated pupil).
- **Structure Segmentation Engine:**
  - **Optic Disc (OD) Localization:** High-intensity circular thresholding & morphological opening.
  - **Fovea Center Extraction:** Low-intensity macular depression located 2.5 OD-diameters temporally.
  - **Retinal Vascular Tree:** Morphological top-hat + adaptive Otsu thresholding tracking vascular caliber.
  - **Microaneurysm (MA) Candidates:** Detection of red-lesion dots in green channel.

---

### Slide 5: Deep Learning Severity Grading & Explainability (MathWorks Req 3 & 4)
- **DR Severity Classifier (5 Classes):**
  - Grade 0: No DR | Grade 1: Mild NPDR | Grade 2: Moderate NPDR | Grade 3: Severe NPDR | Grade 4: Proliferative DR.
  - Backbone: Transfer learning with EfficientNetB0 (`final_model.keras`, 33.4 MB).
  - Clinically Calibrated Margin: Binary referable threshold ($\ge$ Grade 2) with low-confidence routing (<60%).
- **Explainable AI (<30 Second Inference):**
  - True Gradient-weighted Class Activation Mapping Plus Plus (**Grad-CAM++**) computed via exact gradient backpropagation through final convolutional feature maps.
  - Clinically honest claim boundaries: Clearly labeled as activation heatmaps, not automated diagnostic lesion segmentation.

---

### Slide 6: District-Scale Telemedicine & Simulink Simulation (MathWorks Req 5)
- **Scale:** 100,000 patients/year across 50 rural PHCs and 1 District Hospital.
- **Queueing Theory & Discrete-Event Simulation (Simulink / MATLAB):**
  - M/M/c queuing model simulating patient arrivals, edge AI inference, and tele-ophthalmology uplink.
  - **Bandwidth Reduction:** 99.1% network bandwidth saved by processing locally and uploading only anomalous/flagged cases and lightweight metadata.
  - **Ophthalmologist Workload:** Reduced from 100,000 cases to ~16,100 triage cases/year (~62/day, feasible for a single tele-reviewer).
  - **Simulink Engine (`matlab/simulink_telemedicine_model.m`):** Full parametric model generating latency curves, queue depths, and server utilization charts.

---

### Slide 7: Experimental Verification & A/B Trial Results
- **150-Image Benchmark Experiment:**
  - **Baseline Model (No Quality Gate):** 100% of blurry/degraded images received forced, invalid clinical diagnoses.
  - **Our Gated Architecture:** **0% forced predictions** on ungradable images (100% leakage prevention).
  - Bounded Recapture Protocol: Max 2 recapture attempts before auto-escalating to in-person clinical exam.
- **Unit & Integration Tests:** 7 comprehensive test suites passing with 100% clean test execution.

---

### Slide 8: Business Viability, Deployment & Social Impact
- **Hardware Agnostic:** Works with affordable handheld fundus cameras (Remidio, Forus 3nethra, Volk iNview) connected to a low-cost laptop or edge device.
- **Zero Cloud Latency:** Edge inference executes in <1.2 seconds on CPU; fully functional offline in remote villages without internet.
- **Compliance & Privacy:** DICOM and FHIR ready; no unencrypted patient PHI transmitted over public networks.
- **Alignment with Ayushman Bharat Digital Mission (ABDM):** Seamless tele-referral from Village Health Sub-Centres to District Eye Hospitals.
