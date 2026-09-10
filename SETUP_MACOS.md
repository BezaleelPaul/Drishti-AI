# 🍎 macOS Installation & Developer Guide

### Drishti-AI / Netra-AI: AI-Assisted Diabetic Retinopathy Screening Pipeline
**Smart India Hackathon 2026 (Problem Statement SIH26038 • MathWorks)**

---

## 📋 Welcome & Overview

Welcome! This guide gives you everything you need to run **Drishti-AI** on any Mac (**Apple Silicon M1/M2/M3/M4** or **Intel Mac**). 

The platform consists of two main software applications:
1. **Central Clinical & Doctor Console**: Interactive Streamlit web application with 2-model screening, Grad-CAM++ heatmaps, CSME risk biomarkers, PDF dossier export, ABDM FHIR R4 generation, and MATLAB/Simulink 100k telemedicine simulation.
2. **ASHA Mobile & Tele-Review App**: Complete Flutter application connecting to a high-speed FastAPI REST backend bridge for rural field check-in and quality gating.

---

## 💻 System Requirements

* **Operating System**: macOS Monterey (12.0), Ventura (13.0), Sonoma (14.0), or Sequoia (15.0+)
* **Hardware**: Apple Silicon (M1/M2/M3/M4) or Intel Core i5/i7
* **Memory (RAM)**: Minimum 4 GB RAM (pipeline consumes only ~620 MB peak RAM)
* **Disk Space**: ~2 GB free disk space (includes models, dependencies, and test datasets)
* **Python**: Python 3.10, 3.11, or 3.12

---

## ⚡ Quick Start (The 2-Minute Setup)

### Step 1: Unzip & Open Terminal
1. Double-click the ZIP file to extract it, or run:
   ```bash
   unzip Drishti_AI_MacOS_Complete_Software_Kit.zip
   ```
2. Open your Mac **Terminal** (`Command + Space`, type `Terminal`, hit `Enter`).
3. Navigate into the unzipped project folder:
   ```bash
   cd ~/Downloads/"SIH HACKATHON"
   # Or wherever you extracted the folder
   ```

---

### Step 2: Run the Automated Setup Script
We included an automated setup script that creates an isolated virtual environment, installs dependencies, and verifies the pipeline:

```bash
chmod +x setup_mac.sh run_mac.sh
./setup_mac.sh
```

> [!TIP]
> **Why we use a virtual environment:**
> Modern macOS versions (macOS Sonoma & Sequoia) enforce PEP 668 ("externally-managed-environment"). Our script automatically creates and activates a local `./venv` so your system Python remains completely untouched and clean.

---

### Step 3: Launch the Applications

You can use the interactive menu:
```bash
./run_mac.sh
```

Or launch individual components directly:

#### 1. Clinical Screening Dashboard (Streamlit UI)
```bash
source venv/bin/activate
streamlit run demo/app.py
```
👉 Open your browser to **http://localhost:8501**

#### 2. FastAPI REST Backend Server
```bash
source venv/bin/activate
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
```
👉 Interactive API Documentation (Swagger): **http://localhost:8000/docs**

#### 3. Flutter Mobile / Tablet Client (Optional)
If you have the [Flutter SDK](https://docs.flutter.dev/get-started/install/macos) installed:
```bash
cd flutter_app
flutter run -d chrome
# Or to run as native macOS desktop app:
flutter run -d macos
```

#### 4. Run the Full 10-Subsystem Verification Suite
```bash
source venv/bin/activate
python verify_complete_system.py
```

---

## 📂 Detailed Folder Structure Explained

Here is the exact map of what is inside the project and what each folder does:

```text
SIH HACKATHON/
│
├── 🍎 macOS Launchers & Configs
│   ├── setup_mac.sh           # Automated one-click Mac installer
│   ├── run_mac.sh             # Interactive terminal launcher menu
│   ├── SETUP_MACOS.md         # This foolproof Mac guide
│   ├── pyproject.toml         # PEP 517/518 build metadata & dependencies
│   ├── requirements.txt       # Pinned Python package dependencies
│   ├── Makefile               # CLI commands (make setup, make test, make run)
│   ├── Dockerfile             # Containerized deployment specification
│   └── docker-compose.yml     # Zero-config multi-service launcher
│
├── 🧠 AI Pipeline Core (`src/`)
│   ├── quality/               # Model 1: Image Quality Gate & blur/illumination triage
│   │   ├── checker.py         # Multi-scale Laplacian & biological feature triage
│   │   └── enhancer.py        # MathWorks Req 1: Non-destructive CIELAB CLAHE
│   ├── classification/        # Model 2: DR Severity Classifier & Grad-CAM++
│   │   ├── classifier.py      # EfficientNetB0 5-class DR inference engine
│   │   └── gradcam.py         # True gradient backpropagation attention heatmaps
│   ├── clinical_risk/         # Stage 1: Population diabetes risk model (ICMR 2024)
│   │   └── risk_model.py      # Random Forest model on Asian-Indian BMI cutoffs
│   ├── segmentation/          # MathWorks Req 2: Retinal Structure Segmentation
│   │   └── structure_segmenter.py # Optic Disc, Fovea, Vessel Tree, CSME risk
│   ├── simulation/            # MathWorks Req 5: Simulink 100k Telemedicine Model
│   │   └── telemedicine_sim.py    # Discrete-event queuing, 99.1% bandwidth reduction
│   ├── reporting/             # Clinical Dossier & Tele-health Interoperability
│   │   ├── pdf_generator.py   # Hospital-grade printable A4 PDF dossier
│   │   └── fhir_exporter.py   # ABDM FHIR R4 DiagnosticReport (LOINC/SNOMED)
│   └── pipeline/              # Decision Router & Confidence Engine
│       ├── router.py          # 11-node clinical decision flow router
│       ├── confidence.py      # Softmax margin & human review triggers
│       └── schema.py          # Strict dataclass schemas
│
├── 🌐 Web & API Applications
│   ├── demo/                  # Central Clinical Dashboard
│   │   ├── app.py             # Full Streamlit application (1100+ lines)
│   │   ├── custom_style.css   # Medical theme stylesheet
│   │   └── generate_samples.py# Synthetic test generator
│   └── api/                   # FastAPI Backend Bridge (for Flutter & Telehealth)
│       ├── main.py            # FastAPI application entry point
│       ├── database.py        # SQLite schema (patients, screenings, reviews)
│       ├── schemas.py         # Pydantic request/response validation
│       ├── services/          # Singleton AI bridge service
│       └── routes/            # REST endpoints (patients, risk, retinal, review)
│
├── 📱 Mobile / Tablet Client (`flutter_app/`)
│   ├── lib/
│   │   ├── main.dart          # App entry point, Material 3 healthcare theme
│   │   ├── models/            # Data models matching backend schemas
│   │   ├── services/          # ApiService with offline fallback
│   │   └── screens/           # 4 Dedicated Clinical Screens:
│   │       ├── patient_checkin_screen.dart # Screen 1: ABHA Check-in & ICMR risk
│   │       ├── camera_capture_screen.dart  # Screen 2: Quality Gate & Hindi voice
│   │       ├── screening_result_screen.dart# Screen 3: DR Grade, Grad-CAM, SMS
│   │       └── doctor_review_screen.dart   # Screen 4: Tele-Ophthalmologist queue
│   └── assets/images/         # Bundled clinical fundus test images
│
├── 📦 Pre-Trained Weights & External Toolboxes
│   ├── final_model.keras      # Fine-tuned EfficientNetB0 (33.4 MB)
│   ├── diabetes_ml_model.joblib # Trained clinical risk model
│   └── external/              # Research repositories:
│       ├── DR-EfficientNetB0/ # HuggingFace model source & weights
│       └── fundus_image_toolbox/ # Berens Lab PyTorch deep ensembles
│
├── 🧪 Verification Suites & Test Samples
│   ├── verify_complete_system.py # End-to-end benchmark of all 10 subsystems
│   ├── test_api_endpoints.py     # Comprehensive FastAPI endpoint test
│   ├── test_ml_pipeline_upgrade.py # Quality Gate & Grad-CAM++ test
│   ├── tests/                    # Unit, integration, and edge-case tests
│   └── test_samples/             # Real clinical fundus images & test packs
│
├── 📚 Documentation (`docs/`)
│   ├── ARCHITECTURE.md           # Full system architecture
│   ├── HARDWARE_COMPATIBILITY.md # Portability matrix & offline guarantees
│   ├── DECISION_FLOW.md          # 11-node clinical routing logic
│   ├── LABELING_CRITERIA.md      # ICDR clinical grading definitions
│   └── METRICS_AND_EVALUATION.md # QWK, sensitivity, specificity targets
│
└── 🎤 Presentation & Defense (`presentation/`)
    ├── SIH_OFFICIAL_PPT_DECK.md  # Official 8-slide presentation pitch
    ├── JUDGES_QA_DEFENSE.md      # Defense answers for tough judge questions
    └── DEMO_VIDEO_SCRIPT.md      # 3-minute video recording walkthrough
```

---

## 🛠️ Common macOS Troubleshooting & FAQ

### 1. "error: externally-managed-environment"
* **Cause**: macOS Homebrew or system Python restricts `pip install` outside virtual environments.
* **Fix**: Always activate the project venv:
  ```bash
  source venv/bin/activate
  ```

### 2. "command not found: python3" or Command Line Tools prompt
* **Fix**: Install the official Apple Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```
  Then install Python via Homebrew:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew install python@3.11
  ```

### 3. "Port 8501 is already in use"
* **Fix**: Another instance of Streamlit is running. Free port 8501:
  ```bash
  lsof -ti :8501 | xargs kill -9
  ```

### 4. "Port 8000 is already in use"
* **Fix**: Free port 8000:
  ```bash
  lsof -ti :8000 | xargs kill -9
  ```

### 5. macOS Gatekeeper / Quarantine
* If macOS shows a security warning when executing shell scripts:
  ```bash
  xattr -d com.apple.quarantine *.sh
  ```

---

## 🏆 Key Features to Highlight to Judges

When you or your friend present Drishti-AI, emphasize these 4 differentiators:
1. **Model 1 Answers "Can We Trust This Image?" First**: Standard AI models force authoritative grades on blurry fundus photos. Our Quality Gate rejects bad images with 0% diagnostic leakage.
2. **100% Offline Edge Operation**: Runs on cheap CPUs (<180 ms) with zero remote API dependencies and a compact 620 MB RAM footprint.
3. **True Grad-CAM++ & Biomarker Quantification**: Multiscale gradient attention heatmaps overlaid in <1.2 seconds, with microaneurysm candidate counting and CSME risk assessment.
4. **Complete Telemedicine Architecture**: Flutter mobile app for ASHA field workers, Streamlit central console for doctors, ABDM FHIR R4 interoperability, and district-scale Simulink queuing simulation for 100,000 patients.
