# 🎤 TechUtsav 2.0 — Final Expo Pitch & Judge Defense Guide

### Project: **Drishti-AI (Netra-AI)**
### Problem Statement: **SIH26038 (MathWorks) — Explainable AI for Retinal Screening in Rural India**
### Venue: **CMR SOET • 8 October 2026**
### Team: **Bezaleel, Madhu, Akshay, Adithya, Sinduri, Megha**

---

## ⚡ Part 1: The 60-Second Elevator Pitch

> **Practice rule:** Every team member should be able to deliver this naturally in under 60 seconds without sounding like a robot. If judges interrupt, welcome it!

```text
[PROBLEM]
"In rural India, 77 million diabetic patients face preventable blindness, but there is only 1 ophthalmologist per 100,000 people. Worse, standard AI models forced a diagnosis even on blurry, ungradable smartphone captures—causing dangerous misdiagnoses in rural camps."

[SOLUTION]
"We built Drishti-AI: an edge-deployable, clinically-gated screening platform that operationalizes hospital-grade diabetic retinopathy detection for rural Primary Health Centres."

[HOW IT WORKS]
"A multi-stage pipeline first executes an automated Model 1 Quality Gate that rejects defocused or non-retinal images in sub-180 milliseconds, giving real-time Hindi audio guidance to ASHA workers. Diagnostic scans then pass to our DRDetect Ordinal Regression neural network, generating 5-class severity grades alongside Grad-CAM++ lesion explainability in under 1.2 seconds—100% offline on a consumer CPU."

[INNOVATION / USP]
"Unlike commercial black boxes, Drishti-AI has a zero-leakage guarantee—refusing to grade ungradable scans—extracts quantitative CSME macular edema biomarkers, and includes a discrete-event district telemedicine model showing a 99.1% reduction in network bandwidth."

[RESULT & IMPACT]
"Our upgraded clinical grader achieves a 0.8931 Quadratic Weighted Kappa and 99.70% referable sensitivity on 2,810 real clinical images, completely bridging the gap between frontline rural camps and district hospitals."
```

---

## 🎯 Part 2: Complete Judge Q&A Defense (All 13 Checklist Questions)

### Q1: What problem are we solving?
**Answer:**
"We are solving the failure of clinical screening for Diabetic Retinopathy (DR) in rural, underserved populations. 
1. **Access Crisis:** Rural India has an acute shortage of eye specialists (1 per 100,000 citizens).
2. **Technical Bottleneck:** Existing commercial AI systems depend on expensive tabletop fundus cameras (₹15–25 lakhs), continuous high-speed internet, and cloud GPUs.
3. **Clinical Failure Mode:** When handheld, low-cost cameras produce motion-blurred, poorly illuminated, or defocused captures, naive AI forces a false classification on bad data."

---

### Q2: Why does this problem matter?
**Answer:**
"Diabetic Retinopathy is asymptomatic in early stages. By the time a rural farmer notices vision loss, irreversible retinal capillary damage and proliferative neovascularization have already occurred. Early detection prevents 90% of severe vision loss. Screening at the PHC level prevents lifelong disability, preserving livelihoods and reducing secondary healthcare burdens on government district hospitals."

---

### Q3: What exactly did we build?
**Answer:**
"We built an integrated end-to-end clinical screening ecosystem consisting of:
1. **Model 0 (Fundus Domain Gate):** Rejects accidental captures of non-retinal objects (skin, documents, room backgrounds).
2. **Model 1 (Clinical Quality Gate):** Multi-scale Laplacian blur analysis, illumination check, and field-of-view (FOV) triage with non-destructive CIELAB CLAHE enhancement.
3. **Model 2 (DR Severity Classifier):** DRDetect Ordinal Regression network based on EfficientNetB0, classifying 5 stages (No DR, Mild, Moderate, Severe, PDR).
4. **Grad-CAM++ Explainability Engine:** Backpropagates class activation maps in <1.2 seconds on CPU to visually localize microaneurysms and hemorrhages for auditing doctors.
5. **CSME Biomarker Segmentation:** Segmenting optic disc, fovea center, and vessel tree to calculate clinically significant macular edema risk.
6. **Cross-Platform ASHA Client & Doctor Console:** Offline-first Flutter app (Android, Windows, macOS, Web) backed by an authenticated, HIPAA/ABDM FHIR R4-compliant FastAPI backend."

---

### Q4: How does it work? (Step-by-Step Flow)
**Answer:**
```
[1. Patient Check-In] ────► Upstream ICMR Indian-Asian Diabetes Risk Survey
         │
         ▼
[2. Handheld Capture] ────► Model 0 (Domain Gate) ──► Rejects Non-Fundus
         │
         ▼
[3. Quality Triage]   ────► Model 1 Gate (Blur/Illumination/FOV)
         │                     └─► If Bad: Real-time Audio Guidance & Recapture (Max 2)
         ▼
[4. AI Grading]       ────► Model 2 DRDetect Ordinal Regression (Sub-180ms CPU)
         │
         ▼
[5. Explainability]   ────► Grad-CAM++ Lesion Heatmap + CSME Segmentation
         │
         ▼
[6. Clinical Triage]  ────► Bounded Telemedicine Sync / ABDM FHIR R4 / SMS Slip
```

---

### Q5: What is innovative about it? (Our Core USPs)
**Answer:**
"1. **Zero Diagnostic Leakage:** In our benchmark of 150 degraded captures, standard classifiers forced diagnoses on 100% of images. Drishti-AI rejects 100% of ungradable captures with zero leakage.
2. **Sub-180ms CPU-Only Offline Inference:** Requires zero cloud GPU and zero internet connection during field screening.
3. **Ordinal Regression Head:** Instead of fragile independent multi-class softmax probabilities, we enforce clinical severity continuity via ordinal regression thresholds.
4. **Physiological Cause Attribution:** We don't just say 'bad image'—we diagnose the biological root cause (e.g., lens cataract media opacity vs. un-dilated pupil requiring dark room adaptation).
5. **Simulink District Queuing Model:** MathWorks discrete-event model demonstrating 99.1% bandwidth savings and triage scaling for 100,000 district patients."

---

### Q6: What technologies did we use?
**Answer:**
* **Deep Learning & Edge ML:** PyTorch, ONNX Runtime, TFLite (via `flutter_litert`), EfficientNetB0, OpenCV, NumPy, SciPy.
* **Explainability & Biomarkers:** Grad-CAM++, Adaptive Gabor filtering, Morphological Top-Hat/Bottom-Hat vessel segmentation.
* **System Simulation:** MATLAB & Simulink (SimEvents discrete-event queuing network).
* **Backend Bridge:** Python 3.12, FastAPI, Uvicorn, SQLite with WAL mode, SQLCipher encryption, Pydantic v2.
* **Frontend Ecosystem:** Flutter SDK 3.41, Dart, Material 3, Riverpod, Google Fonts.
* **Interoperability & Standards:** HL7 FHIR R4 (ABDM schema), DLT-compliant SMS adapters, WhatsApp Cloud API webhooks.

---

### Q7: What results did we achieve?
**Answer:**
* **Quadratic Weighted Kappa (QWK):** **0.8931** (exceeding standard clinical threshold of 0.80).
* **Referable DR Sensitivity:** **99.70%** (critical safety metric: virtually zero referable patients missed).
* **Macro F1-Score:** **0.6913** (balanced across severe and proliferative minority classes).
* **Domain Rejection Rate:** **100%** on adversarial fixtures (14/14 non-fundus images successfully blocked).
* **Execution Latency:** **< 180 ms** on consumer Intel Core i3 / Ryzen 3 laptops; Grad-CAM in **< 1.2 s** (30x faster than MathWorks' 30-second budget).
* **Code & Pipeline Quality:** **117 Python tests** passing; **42 Flutter tests** passing with 0 compiler warnings.

---

### Q8: What are the limitations? (Honest Clinical Engineering)
**Answer:**
"1. **Monocular 2D Color Fundus:** The system screens 2D color fundus images. It cannot replace 3D Optical Coherence Tomography (OCT) for measuring micron-level retinal thickness.
2. **Optical Aberrations on Sub-₹10,000 DIY Lenses:** Extreme lens flare or severe corneal reflections can trigger false rejections at the quality gate.
3. **Single-Worker Database in Current Build:** The local offline SQLite database is optimized for single-clinic operation; district-level concurrent centralization requires PostgreSQL migration.
4. **Screening Tool, Not Autonomous Diagnostician:** The AI provides decision support and triage; definitive therapeutic intervention (laser/anti-VEGF) must be signed off by a licensed ophthalmologist."

---

### Q9: Why is our solution better than existing approaches?
**Answer:**
| Feature | Commercial Desktop AI (IDx-DR, Google Health) | Naive Hackathon Prototypes | **Drishti-AI (Our Platform)** |
|---|:---:|:---:|:---:|
| **Hardware Cost** | ₹15,00,000+ (Tabletop only) | Web camera / phone | **Agnostic (₹15,000+ Handheld & Desktop)** |
| **Internet Dependency** | Cloud API required | Cloud API required | **100% Offline CPU Execution** |
| **Quality Gating** | Rejects without advice | Forced diagnosis on blur | **Model 1 Gate + Hindi Guidance** |
| **Explainability** | Proprietary / Black Box | None | **Sub-1.2s Grad-CAM++ Lesions** |
| **Indian Demographics** | Western BMI models | None | **ICMR Asian-Indian Risk Gating** |

---

### Q10: What happens if something fails? (Fail-Safe Architecture)
**Answer:**
"We adhere to a strict **'Fail-Closed' Clinical Policy**:
1. **Corrupted / Non-Fundus Capture:** Caught by Model 0 (`IMG_NOT_FUNDUS`). No DR inference ever runs.
2. **Defocus / Inadequate Illumination:** Caught by Model 1 (`IMG_UNGRADABLE`). DR prediction is strictly suppressed; guidance prompt is issued.
3. **Max Recaptures Exceeded:** Bounded retry policy caps attempts at 2. If quality fails twice, the case is routed to **Human Clinical Review** with suspected cataract/media opacity.
4. **Model Crash or Weight Corruption:** System automatically triggers `AI_UNAVAILABLE` status and routes directly to tele-ophthalmologist review with raw image preservation.
5. **No Internet Connectivity:** All screenings and encrypted patient logs are persisted locally in SQLCipher and automatically flushed via idempotent `/sync` when internet is restored."

---

### Q11: What is the real-world deployment potential?
**Answer:**
"Drishti-AI is designed directly for India's public health delivery hierarchy:
* **Level 1 (Sub-Centres / Village Camps):** ASHA workers carrying Android tablets or low-cost smartphones fitted with smartphone ophthalmoscope attachments (like Volk iNview or Remidio).
* **Level 2 (Primary Health Centres - PHCs):** Mid-level health workers operating refurbished laptops and tabletop cameras (e.g., Forus 3nethra).
* **Level 3 (Community & District Hospitals):** Ophthalmologists using the central Doctor Console to audit flagged referrals and review Grad-CAM heatmaps.
Because our pipeline integrates ABDM Ayushman Bharat Digital Mission FHIR R4 JSON standards, it can plug directly into state health registry portals."

---

### Q12: What is the approximate cost?
**Answer:**
* **Software Licensing:** 100% Free & Open Source (Python, Flutter, FastAPI).
* **Hardware Capex:** 
  * Re-uses existing PHC government laptops (Core i3 / 4GB RAM — zero new hardware needed).
  * Compatible with handheld camera attachments costing ₹15,000 – ₹60,000 (compared to ₹20,00,000 for proprietary foreign machines).
* **Per-Screening Cost:** Estimated at **< ₹15 per patient** (including battery, electricity, and local health worker honorarium), saving families thousands in travel and lost daily wages."

---

### Q13: What would we improve next? (Roadmap)
**Answer:**
"1. **Direct UVC Hardware Streaming:** Integrate USB Video Class (UVC) OTG drivers to display real-time live fundus camera video streams inside Flutter.
2. **Micro-Lesion Counting:** Transition from Grad-CAM heatmaps to semantic segmentation bounding boxes for individual microaneurysms and hard exudates.
3. **Statewide Distributed Scaling:** Replace SQLite with distributed PostgreSQL and Redis message brokers for handling 500+ PHCs concurrently.
4. **Prospective Clinical Trial:** Submit an IRB protocol to run multi-center field validation at a regional eye institute (e.g., Aravind or LV Prasad Eye Institute)."

---
