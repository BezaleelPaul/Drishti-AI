# AI-Assisted Diabetic Retinopathy Screening Pipeline

### SIH 2026 • Software Prototype Track
**Final Professional Architecture & Execution Plan — Locked to the Approved Decision Flow**

---

## 🎯 Executive Summary & Problem Statement: Bridging the "Last-Mile" Clinical Gap

> **"We aren't claiming to invent 5-class deep learning classification — Google Health (Gulshan et al., JAMA 2016) and IDx-DR already proved neural networks can grade diabetic retinopathy under curated hospital conditions. Our innovation is solving the real-world deployment failure modes that prevent these models from working in rural India: democratizing screening on ₹15,000 edge hardware, eliminating the catastrophic 'garbage-in, garbage-out' ungradable image problem, and providing quantitative clinical biomarkers offline."**

### 🧭 The 4 Operational Questions Governing Every Design Decision
What hasn't been solved by prior laboratory models is getting an AI screening system to run, day after day, in a rural Primary Health Centre (PHC) with unreliable power, patchy connectivity, a ₹15,000 camera attachment, a non-specialist operator, and no guarantee of a fixed operating system. Drishti-AI was engineered from Day 1 against four questions, in strict priority order:
1. **Will it keep running here?** (Zero cloud dependency, fault-tolerant offline execution)
2. **Can everyone reach it?** (2G/3G low-bandwidth resilience, district-scale triage)
3. **Can everyone use it?** (Frontline ASHA/ANM usability, bilingual Hindi/English guidance)
4. **Will it run on whatever hardware they actually have?** (Low-cost laptops & commodity cameras, no vendor lock-in)

---

### 🏥 The Real-World Reality vs. The Laboratory Myth
Over **77 million adults in India live with diabetes**, and Diabetic Retinopathy (DR) is the leading cause of preventable adult blindness. With only **1 ophthalmologist per 100,000 rural citizens**, universal hospital-based specialist screening is mathematically impossible.

While pioneering deep learning research (e.g., Google Health ARDA, EyePACS) achieved human-expert grading accuracy on high-end hospital tabletop cameras (Zeiss, Topcon) backed by cloud GPUs, **these centralized systems fail when deployed in rural community screening camps, mobile vans, and Primary Health Centres (PHCs)**:

1. **The "Garbage-In, Garbage-Out" Blindspot:**  
   In community camps, ASHA workers and field technicians use low-cost handheld fundus attachments (Remidio NM-FOP, Forus 3Nethra, Volk iNview) under non-mydriatic (undilated pupil) conditions. Up to **25%–35% of captured images suffer from motion blur, poor illumination, corneal reflections, or eyelid occlusion**. A standard classifier forced to grade every capture outputs an authoritative-looking yet dangerously wrong diagnosis on ungradable pixels — causing missed proliferative disease or flooding district hospitals with false referrals.
2. **Cloud Dependency & Bandwidth Chokepoints:**  
   Cloud-based screening requires uploading 5–15 MB uncompressed raw images per eye over 4G/5G networks. In rural PHCs with intermittent 2G/3G connectivity or frequent power outages, cloud inference creates unacceptable latency and screening camp backlogs.
3. **Black-Box Classification vs. Actionable Clinical Biomarkers:**  
   A simple prediction label (e.g., *"Grade 2: Moderate NPDR"*) does not tell the rural physician *why* or whether the macula is in immediate danger. Clinicians require quantitative measurement of macular distance (CSME risk) and explainable visual evidence before committing scarce referral resources.
4. **District-Scale System Overload:**  
   Without localized triage, sending every screening patient to district hospitals overwhelms the few existing retinal specialists with healthy eyes (70%+ of screened populations).

---

### 💡 Drishti-AI's Architectural Contribution: Rural Edge Operationalization

Drishti-AI is purpose-engineered to bridge this exact last-mile gap as mandated by **Smart India Hackathon 2026 (Problem Statement SIH26038 • MathWorks)**:

- **Model 1 Image Quality Gating (Abstention Before Grading):** Image reliability is the first decision the system makes. Degraded or non-fundus captures are immediately rejected with sub-second actionable feedback (e.g., *"Blur detected: Hold camera steady"*, English audio prompts with Hindi on-screen guidance for ASHA workers), strictly bounded to 2 recaptures before human review.
- **100% Offline Edge Computing (field budget ≤1.4 s end-to-end on CPU):** The entire pipeline (Model 1 Quality Gate, Model 2 5-Class Classifier, Retinal Anatomical Segmentation, and Grad-CAM++ Explainability) runs natively on consumer laptops (Intel Core i3 / AMD Ryzen 3, 4GB RAM) with zero internet and zero cloud GPU reliance. Measured latency on Apple M3 dev machine (see `results/benchmark.json`, re-run `python benchmark_latency.py` on target hardware): quality gate ~1–3 ms, classifier ~67 ms warm, full screening ~73–82 ms warm. Field budget on i3/4GB-class hardware: ≤1.4 s including cold-start margin.
- **Quantitative Retinal Biomarkers (MathWorks Req 2):** Automated segmentation of Optic Disc, Fovea center, and Retinal Vascular Caliber enables physical Euclidean distance calculation for Clinically Significant Macular Edema (CSME) risk.
- **District-Scale Bandwidth Optimization (Simulink Model):** A discrete-event queuing simulation across 20 rural PHCs + 5 mobile vans and 100,000 patients proves a **99.1% reduction in telemetry bandwidth** (439.9 GB down to 3.8 GB) and cuts required doctor review capacity from ~4 to ~1 tele-reviewer per 100k patients.

```
                      [ Raw Fundus Photograph ]
                                 │
                                 ▼
                     [ 1. Image Quality Gate ] ◄── (Model 1)
                                 │
               ┌─────────────────┼─────────────────┐
               ▼                 ▼                 ▼
            [ GOOD ]       [ BORDERLINE ]       [ BAD ]
               │                 │                 │
               │          [Reassessment]      [Recapture]
               │           (Stricter Th)      (Max 2 retries)
               │                 │                 │
               │            ┌────┴────┐            │
               │        (Cleared)  (Failed)        │
               │            │         └────────┐   │
               ▼            ▼                  ▼   ▼
        [ Reliable Original Image ]      [ Human Review ]
                    │                    (Operator Level)
                    ▼
          [ 2. DR Classification ] ◄── (Model 2: 5-Class)
                    │
                    ▼
          [ Confidence Check ] ─────► [ Clinical Review ]
                    │                 (Ophthalmologist)
                    ▼
          [ Grad-CAM Heatmap ]
                    │
                    ▼
          [ Final Screening Report ]
```

---

## 🏛️ The Four Core Design Pillars

Drishti-AI is structured around four architectural pillars explicitly formulated for rural Indian public healthcare:

### 1. ♻️ Sustainability (Modest Compute & Resource Longevity)
The pipeline is engineered to run indefinitely on modest, low-power hardware rather than depending on recurring cloud subscriptions:
- **Zero Cloud Compute Costs:** Inference runs on-device/on-edge, ensuring a Primary Health Centre (PHC) never pays an ongoing cloud compute or API bill just to keep screening citizens.
- **99.1% Data Reduction:** Edge-filtering cuts data volume from 439.9 GB raw fundus imagery down to 3.8 GB of structured telemetry and flagged cases before transmission.
- **Hardware Longevity:** Designed to operate on existing ₹15,000 laptops and legacy equipment for years without requiring forced hardware refresh cycles.
- **Waste Elimination via Quality Gating:** Rejecting an ungradable image before it reaches the classifier prevents wasted compute cycles, avoids erroneous referrals, and eliminates costly repeat visits.

### 2. 📡 Availability (Uninterrupted Service Under Hostile Conditions)
The system remains operational when connectivity, electrical power, or specialist personnel fail:
- **Offline-First Screening:** Full on-site screening, quality verification, and clinical reporting operate with zero live internet connection. Central sync occurs opportunistically when a network becomes available.
- **2G/3G Bandwidth Resilience:** Lightweight compressed packets ensure functionality even on intermittent rural cellular links.
- **District-Scale Validation:** Validated via a discrete-event queuing simulation across 100,000 patients/year, 20 PHCs + 5 mobile vans, and 1 district hospital.
- **Specialist Capacity Multiplier:** Reduces required doctor review capacity from ~4 down to ~1 tele-reviewer per 100,000 patients, breaking the rural specialist bottleneck.

### 3. 👥 Accessibility (Operated by Frontline Workers, Understandable by Patients)
Screening is designed for the people actually present at a rural PHC, not just specialists in tertiary hospitals:
- **ASHA & Technician Usability:** Operated by community health workers (ASHAs/ANMs) with plain-language, actionable recapture feedback.
- **Multilingual Patient Communication:** Bilingual (English + Hindi) patient-facing reports today with English audio prompts and Hindi on-screen guidance, with Tamil, Telugu, and Kannada roadmap support for South Indian high-burden regions.
- **Commodity Camera Compatibility:** Validated on low-cost (~₹15,000) portable fundus attachments (Remidio, Forus 3Nethra, Volk iNview) rather than million-rupee tabletop hospital cameras.
- **At-a-Glance Triage:** Immediate visual indicators (Clear / Review / Urgent) accompanied by ICDR technical grades.

### 4. 🔓 Platform Independence (Zero Vendor Lock-In & Open Standards)
Health systems are never locked into a single proprietary vendor, operating system, or cloud provider:
- **100% Open-Source Foundation:** Released under permissive open-source licensing to allow unrestricted public health inspection, adaptation, and auditing.
- **Cross-Platform Compatibility:** Runs natively across Windows, macOS (Apple Silicon M-Series & Intel), Linux, and Docker containers.
- **Healthcare Interoperability:** Implements international standards including **HL7 FHIR R4**, SNOMED CT, and LOINC, with direct alignment to the **Ayushman Bharat Digital Mission (ABDM)** ecosystem.
- **Sensor-Agnostic Processing:** Decoupled from proprietary camera SDKs, ingesting standard DICOM, JPEG, and PNG captures.

---

## 🔄 The Clinical Decision Flow Through Those Four Lenses

| Clinical Step | Operational Mechanism | Design Pillar Addressed |
| :--- | :--- | :--- |
| **1. Patient Check-In** | Upstream clinical risk scoring (ICMR 2024 BMI/HbA1c criteria); directs at-risk patients to blood labs before unnecessary imaging | **Availability** (protects imaging bandwidth) & **Sustainability** (avoids unneeded compute) |
| **2. Image Capture** | Frontline technician captures fundus image on portable attachment (~₹15,000) | **Accessibility** (non-specialist operation) & **Platform Independence** (hardware-agnostic) |
| **3. Quality Gate (Model 1)** | Evaluates blur, illumination, contrast, and FOV coverage on-device; rejects ungradable captures with plain-text/voice prompts | **Sustainability** (zero wasted compute) & **Accessibility** (clear operator guidance) |
| **4. DR Classifier (Model 2)** | Runs 5-class grading (Grades 0–4) *only* on validated, reliable images (~67 ms warm-CPU on dev machine; field budget ≤1.4 s full pipeline) | **Availability** & **Sustainability** (zero cloud round-trip) |
| **5. Grad-CAM++ Visual Evidence** | Computes true gradient backpropagation heatmap in <1.2s on CPU | **Accessibility** (clinician sees *why*, not just a black-box score) |
| **6. Structural Segmentation** | Automatically segments Optic Disc, Fovea, and vessels to measure Euclidean distance for CSME risk | **Availability** (speeds specialist review to <30s per referable case) |
| **7. Dual-Tier Safety Check** | Low confidence (<60%) or high risk (Grade 3/4) automatically flags for ophthalmologist over-read | **Safety & Regulatory Compliance** (human-in-the-loop) |
| **8. Bilingual Reporting** | Generates bilingual English/Hindi PDF report with FHIR R4 JSON | **Accessibility** (patient comprehension) & **Platform Independence** (ABDM integration) |
| **9. Telemedicine Uplink** | Only flagged/referable cases and lightweight metadata sync over rural 2G/3G | **Availability** & **Sustainability** (99.1% network bandwidth saved) |

---

## ⚖️ What This System Is NOT Claiming (Honest Scientific & Regulatory Guardrails)

To maintain scientific integrity and clinical rigor, the Drishti-AI team explicitly states our operational boundaries:

1. **We are NOT claiming to have invented image-quality gating as a concept:**  
   Quality verification is an established, expected component of serious clinical DR screening (Google ARDA, IDx-DR, EyeArt). Our contribution is an independent, lightweight, open-source implementation explicitly optimized for rural Indian edge constraints and low-cost handheld optics.
2. **We are NOT claiming active medical device certification:**  
   Real-world clinical deployment requires statutory CDSCO Medical Device Software approval (Class B/C under India’s 2026 guidance) and strict DPDP Act compliance for patient data privacy. Drishti-AI's human-in-the-loop, abstain-and-escalate architecture is intentionally designed to support that regulatory pathway, never to circumvent it.
3. **We are NOT claiming diagnostic accuracy beyond validated boundaries:**  
   Confidence intervals are reported transparently. Grad-CAM++ is clearly presented as an attention focus visualization, **not automated lesion boundary segmentation**. Every high-risk, ambiguous, or low-confidence capture is mandatorily escalated to a human ophthalmologist.

---

## 📦 Downloaded External Assets

This project integrates the two essential research resources downloaded and prepared in `external/`:

1. **`external/DR-EfficientNetB0/`** ([Hugging Face Hub](https://huggingface.co/Aldahmashi/DR-EfficientNetB0)):
   - Fine-tuned **EfficientNetB0** (`final_model.keras`, 33.4 MB) for 5-class DR grading on **APTOS 2019 Blindness Detection** (No DR, Mild NPDR, Moderate NPDR, Severe NPDR, Proliferative DR).
2. **`external/fundus_image_toolbox/`** ([Berens Lab GitHub](https://github.com/berenslab/fundus_image_toolbox)):
   - State-of-the-art fundus image toolbox featuring 10-model quality prediction ensembles, circular cropping, fovea/optic disc localization, and vessel segmentation.

---

## 📂 Repository Structure (Section 10 Specification)

```text
SIH HACKATHON/
├── src/
│   ├── quality/             # Model 1: Image quality checker, threshold configs, metrics
│   │   ├── __init__.py
│   │   └── checker.py
│   ├── classification/      # Model 2: DR 5-class severity classifier & Grad-CAM engine
│   │   ├── __init__.py
│   │   ├── classifier.py
│   │   └── gradcam.py
│   └── pipeline/            # Decision flow router, confidence evaluation, schemas
│       ├── __init__.py
│       ├── schema.py
│       ├── confidence.py
│       └── router.py
├── tests/
│   ├── unit/                # Per-module unit tests (quality, classifier, confidence)
│   │   ├── test_quality.py
│   │   ├── test_classifier.py
│   │   └── test_confidence.py
│   ├── integration/         # Decision flow integration tests (Good, Bad, Borderline)
│   │   └── test_pipeline_flow.py
│   └── edge_cases/          # Section 18 edge case validations
│       └── test_edge_cases.py
├── kaggle/                  # Kaggle GPU training exports (N1 to N4)
│   ├── N1_DR_Classifier.py
│   ├── N2_Image_Quality.py
│   ├── N3_Explainability.py
│   └── N4_Vessel_Segmentation.py
├── demo/                    # Interactive Streamlit demo & test assets
│   ├── app.py
│   ├── generate_samples.py
│   └── sample_images/       # Pre-generated test cases for demo scenarios
├── docs/                    # Architectural and clinical documentation
│   ├── ARCHITECTURE.md
│   ├── DECISION_FLOW.md
│   ├── LABELING_CRITERIA.md
│   ├── METRICS_AND_EVALUATION.md
│   └── DATASET_STRATEGY.md
├── presentation/            # SIH presentation slides and pitch guide
│   └── PITCH_AND_SLIDES_OUTLINE.md
├── results/                 # Metrics outputs, reports, and Grad-CAM overlays
├── external/                # Pretrained models & upstream packages
│   ├── DR-EfficientNetB0/
│   └── fundus_image_toolbox/
├── requirements.txt         # Core dependencies
├── run_pipeline.py          # Command-line screening runner
└── README.md                # Project documentation
```

---

## 🔒 Non-Negotiable Rules Enforced in Code

1. **Non-Destructive Processing (Section 20):**
   - **No runtime enhancement**, CLAHE, sharpening, or generative filters are applied before prediction. The image reaching Model 2 is pixel-for-pixel the same retinal photograph that reached Model 1.
2. **Abstention on Unreliable Images (Section 3/18):**
   - No Bad or still-unreliable image is ever handed to Model 2. Bad images produce **"DR Prediction: Not generated"** with a specific recapture reason code.
3. **Bounded Recaptures (Section 5/7):**
   - A hard cap of **2 recaptures** per patient session is strictly enforced. Upon hitting the cap, the case is force-escalated to human review.
4. **Mandatory High-Risk Override (Section 7):**
   - Predictions of Grade 3 (Severe NPDR) or Grade 4 (Proliferative DR) are **always** flagged for ophthalmologist over-read, regardless of model confidence.
5. **Two-Tier Human Review (Section 9):**
   - Separates *Operator-Level review* (camera repositioning / recapture) from *Clinical-Level review* (specialist diagnosis & referral urgency).

---

## 🚀 Quickstart Guide

### Option A: One-Command Containerized Run (Recommended for Judges)
Run the entire platform with zero local dependency installation:
```bash
docker compose up
```
Open **http://localhost:8501** in your browser.

### Option B: Local Python Environment
Using Python 3.10+:
```bash
# 1. Install dependencies
make setup
# Or: pip install -r requirements.txt

# 2. Run the full verification test suite (<1s execution)
make test
# Or: python verify_complete_system.py

# 3. Launch interactive Streamlit demo UI
make run
# Or: streamlit run demo/app.py
```

### Option C: CLI Batch Screening
Run automated screening across test packs:
```bash
python run_pipeline.py --input_dir test_samples/01_real_clinical_fundus --output_dir results
```

---

## ⚡ Edge Hardware Portability & Offline Guarantees

- **100% Offline Capable**: Zero runtime API calls, telemetry, or external weight downloads.
- **Low Memory & CPU Optimized**: Inference runs natively on cheap laptop CPUs (Intel Core i3 / AMD Ryzen 3, 4GB RAM); field budget **≤1.4 s** end-to-end (measured ~80 ms warm on Apple M3 dev machine).
- **Cross-Platform Compatibility**: Fully validated on Windows, Linux, and macOS with containerized Docker images and GitHub Actions CI matrix.

## 📋 Sample Screening Reports (Section 25)

#### Accepted Graded Case:
```yaml
Image Quality:    GOOD
Quality Status:   Reliable
DR Prediction:    Grade 2 — Moderate NPDR
Confidence:       87.4%
Explainability:   Grad-CAM generated
Action:           Refer for ophthalmic evaluation / human review per workflow
```

#### Rejected Ungradable Case:
```yaml
Image Quality:    BAD
Reason:           Inadequate illumination / underexposure / Severe blur
DR Prediction:    Not generated
Action:           Recapture image. Do not display a DR grade for an image that fails the reliability gate.
```

---

## 👥 Hackathon Milestone Plan (Internal: 15 Sept 2026)

- **Day 1 (7 Sep):** Scope freeze, architecture locked, directory structure established. *(Completed)*
- **Day 2 (8 Sep):** Dataset preparation & baseline setup. *(Completed)*
- **Day 3 (9 Sep):** DR Model 2 training, class weighting & QWK metrics. *(Completed)*
- **Day 4 (10 Sep):** Image Quality Gate (Model 1) feature checks & threshold tuning. *(Completed)*
- **Day 5 (11 Sep):** Reassessment logic & pipeline integration. *(Completed)*
- **Day 6 (12 Sep):** Confidence scoring & Grad-CAM overlays. *(Completed)*
- **Day 7 (13 Sep):** A/B/C experimental comparisons & safety metric compilation. *(Completed)*
- **Day 8 (14 Sep):** Freeze demo scenarios, slide deck, and presentation rehearsal.

---

## 👥 Engineering Team & Module Ownership

| Team Member | Role | Primary Modules Owned | Key Deliverables |
| :--- | :--- | :--- | :--- |
| **Bezaleel** | Team Lead & Full-Stack Architect | Pipeline Decision Router, Streamlit UI, FastAPI Backend, Cross-Platform Integration | End-to-end clinical flow, zero-config Windows & macOS setups, production Docker stack |
| **Madhu** | Clinical Lead & Biomedical Engineer | Upstream Clinical Risk Engine, Retinal Structure Segmentation, Clinical Validation | ICMR 2024 guidelines calibration, OD/Fovea Euclidean CSME risk distance, clinical report validation |
| **Akshay** | Deep Learning & Operations Lead | EfficientNetB0 DR Classifier, Grad-CAM++ Engine, MATLAB/Simulink Queuing Model | APTOS 2019 model training (QWK metrics), <1.2s CPU Grad-CAM++, 100k-patient Simulink simulation |
| **Adithya** | Safety & Verification Lead | Test Frameworks, A/B Benchmark Experiments, Edge-Case Hardening, Telemedicine Metrics | 150-sample benchmark dataset, 0% forced-prediction validation on ungradables, safety guardrail metrics |
| **Sinduri** | Lead UI/UX Designer | ASHA Mobile Client UX, Field Worker Workflow, Design System & Figma Kits | Low-cognitive-load ASHA mobile screens, camera recapture prompts, bilingual referral slips, `sinduri_uiux_kit/` |
| **Megha** | Lead UI/UX Designer | Doctor Diagnostic Console, Tele-Ophthalmology Dashboard, Clinical Data Visualization | Specialist over-read workbench, Grad-CAM++ lesion heatmaps, quantitative CSME biomarker overlays, ABDM FHIR report layouts |

---

## 💬 The Engineering Manifesto

> *"We’re not building a demo, and we’re not claiming to have invented the underlying detection technique. We’re building the complete, honest, open-source system that makes a validated approach actually reach the people who need it — running sustainably on modest hardware, staying available without reliable power or internet, usable by a technician rather than a specialist, and independent of any single platform or vendor. The web UI is just how judges interact with it. The real project is everything that makes it work outside a hospital."*  
> — **Bezaleel (Team Lead / Full-Stack Architect)**

