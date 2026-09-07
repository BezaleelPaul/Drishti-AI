# AI-Assisted Diabetic Retinopathy Screening Pipeline

### SIH 2026 • Software Prototype Track
**Final Professional Architecture & Execution Plan — Locked to the Approved Decision Flow**

---

## 🎯 Executive Summary & Problem Statement

Automated diabetic retinopathy (DR) screening in real-world community field settings (camps, rural Primary Health Centres, mobile screening vans) frequently encounters degraded retinal captures: blurred focus, poor illumination, severe glare, or off-center alignment.

A standard AI classifier forced to grade every image regardless of quality will still output an authoritative-looking grade on ungradable data. **Our architecture directly solves this failure mode by making image reliability the first decision the system makes.**

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

### 1. Environment Setup
Using Python 3.10+:
```bash
pip install -r requirements.txt
```

### 2. Run the Full Test Suite
Run unit tests, pipeline flow integration tests, and edge case validations:
```bash
python -m unittest discover -s tests -p "test_*.py"
```

### 3. Run Pipeline via CLI
Test all demo scenarios or run on any fundus photograph:
```bash
# Generate sample images and test the pipeline
python demo/generate_samples.py
python run_pipeline.py --input_dir demo/sample_images --output_dir results

# Or run on a single image
python run_pipeline.py --image path/to/fundus.jpg
```

### 4. Launch the Interactive Demo UI
Launch the Streamlit web application:
```bash
streamlit run demo/app.py
```

---

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
- **Day 2 (8 Sep):** Dataset preparation & baseline setup.
- **Day 3 (9 Sep):** DR Model 2 training, class weighting & QWK metrics.
- **Day 4 (10 Sep):** Image Quality Gate (Model 1) feature checks & threshold tuning.
- **Day 5 (11 Sep):** Reassessment logic & pipeline integration.
- **Day 6 (12 Sep):** Confidence scoring & Grad-CAM overlays.
- **Day 7 (13 Sep):** A/B/C experimental comparisons & safety metric compilation.
- **Day 8 (14 Sep):** Freeze demo scenarios, slide deck, and presentation rehearsal.
