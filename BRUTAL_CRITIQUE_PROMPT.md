# BRUTAL PROJECT CRITIQUE — DRISHTI-AI (SIH 2026)

You are a senior medical AI engineer, a hackathon judge who has seen 200+ submissions, and a clinical safety officer. Your job is to DESTROY this project's weak points so we can fix them before presentation.

Be ruthless. Be specific. No flattery. No "good effort" nonsense.

---

## CONTEXT

This is a submission for SIH 2026, Problem Statement SIH26038 (MathWorks). The project is "Drishti-AI" — an AI-Assisted Diabetic Retinopathy Screening Pipeline for rural India. It uses a 2-model pipeline: Model 1 (Image Quality Gate) → Model 2 (DR Severity Classifier with Grad-CAM). It also includes a clinical risk engine, retinal segmentation, Simulink simulation, PDF/FHIR reporting, and a Streamlit demo.

The project repository is at: `C:\Users\bezal\Downloads\SIH HACKATHON`

The source code is in `src/`, demo in `demo/`, tests in `tests/`, docs in `docs/`, presentation in `presentation/`, Kaggle training notebooks in `kaggle/`, and MATLAB/Simulink in `matlab/`.

---

## YOUR TASK

Read the entire project — every source file, every doc, every test, the README, the presentation materials, the demo app — and then produce a BRUTAL critique covering:

### 1. TECHNICAL WEAKNESSES
- Are the ML models actually well-trained? What's the evidence?
- Is the quality gate actually reliable or just hardcoded thresholds?
- Does the Grad-CAM actually work or is it broken?
- Are the tests actually testing anything meaningful?
- Is the code production-quality or hackathon slop?
- Are there obvious bugs, race conditions, or failure modes?
- Is the Simulink model actually simulated or just described?
- Does the FHIR export actually produce valid FHIR?

### 2. CLINICAL SAFETY GAPS
- Would a real ophthalmologist trust this system?
- Are the ICMR guidelines actually correctly implemented?
- Is the confidence calibration real or fake?
- Could this system harm a patient?
- What happens when the model encounters something it's never seen?
- Are the "safety rules" actually enforced in code or just claimed in docs?

### 3. PRESENTATION & DEMO RISKS
- What questions will judges ask that we can't answer?
- What will make judges laugh at us?
- What looks impressive but is actually hollow?
- What looks hollow but is actually impressive (and we're not highlighting it)?
- Is the demo just a pretty UI over a fragile pipeline?
- Can the demo actually run live without crashing?

### 4. HACKATHON STRATEGY FAILURES
- Are we solving the right problem or just building what we know?
- Is our "unique differentiator" actually unique?
- Are we over-engineering things judges don't care about?
- Are we under-engineering things judges will absolutely ask about?
- Is our 8-day sprint plan realistic or delusional?
- Who on the team is a bottleneck and why?

### 5. WHAT THE WINNING PROJECT HAS THAT WE DON'T
- What does the 1st place project at SIH look like?
- What are we missing that separates "top 10" from "winner"?
- What's the one thing a judge will remember about our project — and is it the right thing?

### 6. HARDWARE COMPATIBILITY & "RUNS ANYWHERE" FAILURE
This project targets rural India. It MUST work on garbage hardware with no internet. Critique:

- **Camera Compatibility:** The app lists 4 camera models (Forus 3nethra, Remidio, Volk iNview, Desktop). Are the quality thresholds ACTUALLY tuned per camera, or is it the same hardcoded threshold with a different label? Check `src/quality/checker.py` and `demo/app.py` lines 246-297.
- **CPU vs GPU:** Does the pipeline actually run on a cheap laptop CPU (i3/4GB RAM) or does it silently require CUDA/GPU? Check if PyTorch is using CUDA anywhere. Check `final_model.keras` size — is 33MB model realistic for CPU inference?
- **OS Compatibility:** Does this actually run on Windows, Linux, AND macOS? Or did you only test on one OS? Check path handling (backslash vs forward slash), check if OpenCV headless is needed, check if `pytorch-grad-cam` even installs on all platforms.
- **Offline Mode:** The README claims "offline-ready." Prove it. Can the entire pipeline run with ZERO internet? Does it try to download fonts, models, or validation data at runtime? Check for any `requests.get()`, `urllib`, or model download calls.
- **Dependency Hell:** `requirements.txt` lists `pytorch-grad-cam>=0.2.1` — this package is BROKEN on Python 3.12 and many systems. We hit this already. What else is broken? Does `torch` actually install on ARM (Raspberry Pi)? On Windows without CUDA?
- **The "Runs Anywhere" Lie:** If a judge in a different city clones this repo and runs `pip install -r requirements.txt && streamlit run demo/app.py`, will it ACTUALLY work? Or will they hit 5 different errors? Test this assumption.
- **Model Loading:** Does `final_model.keras` load correctly on every system? Keras 3 has backend issues (TensorFlow vs JAX vs PyTorch). What backend is it using? Is it pinned?
- **File Paths:** Check for hardcoded absolute paths like `C:\Users\bezal\...` anywhere in the codebase. These will break on every other machine.
- **Streamlit Version:** `streamlit>=1.30.0` — we're running 1.58.0. Is the app compatible with older versions a judge might have?
- **Docker/Deployment:** Is there a Dockerfile? A `pyproject.toml`? A `Makefile`? Or is the only way to run this "clone the repo, hope Python works, hope dependencies install"?
- **Memory Footprint:** How much RAM does the pipeline consume? If a rural PHC has a ₹15,000 laptop with 4GB RAM and Chrome open, will this crash?
- **Startup Time:** How long does the Streamlit app take to cold-start? If a judge waits 60 seconds, they'll walk away.

### 7. WHAT THE WINNING PROJECT HAS THAT WE DON'T
- What does the 1st place project at SIH look like?
- What are we missing that separates "top 10" from "winner"?
- What's the one thing a judge will remember about our project — and is it the right thing?
- Can a judge clone this repo and run it in under 60 seconds? If not, we lose.
- Is there a one-command setup (`make setup` or `docker compose up`)? If not, we look amateur.
- Does the project have a `Dockerfile`? A CI/CD pipeline? Any sign of software engineering maturity?

### 8. HONEST GRADE
Give the project an honest grade out of 10 for:
- Technical depth
- Clinical validity
- Code quality
- Demo impact
- Presentation readiness
- Hardware compatibility & portability
- Overall hackathon competitiveness

Then tell us: **What is the single most important thing we should fix in the next 48 hours?**

---

## RULES

- Do NOT be nice. We don't need encouragement. We need to know what's broken.
- Do NOT say "this is good but..." — just tell us what's wrong.
- Do NOT assume something works because the docs say it works. Verify against the actual code.
- Do NOT grade on a curve. Grade against what a winning SIH submission looks like.
- DO be specific. "Your confidence calibration is broken because line X in file Y does Z" is useful. "Improve your confidence" is useless.
- DO compare against real medical AI systems (IDx-DR, Google Health DR, Aravind Eye Hospital pipeline).
- DO think like a judge who has to pick 1 winner from 50 teams.
- DO assume the judge's laptop is a 4-year-old Windows machine with 4GB RAM, no GPU, and 2MBbps internet.
- DO assume the rural PHC has a ₹15,000 laptop, no internet, and a USB fundus camera.
- DO test whether `pip install -r requirements.txt` actually succeeds cleanly on a fresh Python 3.12 install.
- DO check if the app crashes when camera hardware is switched mid-session.
- DO check if the app works when the model file is missing or corrupted.
- DO check what happens when someone uploads a PNG, BMP, TIFF, or a 20MB image.

---

## FORMAT

Structure your critique as:

### CRITIQUE 1: [Title]
**Severity:** CRITICAL / HIGH / MEDIUM / LOW
**What's Wrong:** [Specific description with file:line references]
**Why It Matters:** [What happens when judges/patients encounter this]
**Fix:** [Exact steps to resolve it, with code if possible]

Repeat for every issue found.

End with:
### TOP 5 THINGS TO FIX BEFORE PRESENTATION
1. ...
2. ...
3. ...
4. ...
5. ...

### HARDWARE & PORTABILITY FIX LIST
For every issue found in Section 6, provide:
- **What breaks:** [Specific hardware/OS/dependency scenario]
- **Who it affects:** [Judge on Windows? PHC worker on Linux? Demo on Mac?]
- **Fix:** [Exact command, code change, or configuration needed]
- **Verification:** [How to prove it works after fixing]

### THE HONEST TRUTH
[One paragraph brutal summary of where this project actually stands]

---

Now read every file in the project and begin.

---

## BONUS: GENERATE THE FIXES

After the critique, also generate:

### 1. A working `Makefile` or `setup.sh` that does:
```bash
# One command to get the project running from fresh clone
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
python -c "import torch; print('PyTorch OK:', torch.__version__)"
python -c "import streamlit; print('Streamlit OK:', streamlit.__version__)"
python demo/generate_samples.py
echo "Ready. Run: streamlit run demo/app.py"
```

### 2. A `Dockerfile` that:
- Uses a slim Python 3.11 base (not 3.12 — too many compatibility issues)
- Installs all dependencies cleanly
- Copies the model files
- Exposes port 8501
- Runs the Streamlit app
- Works on any Docker-capable machine

### 3. A `pyproject.toml` or `setup.cfg` that:
- Pins Python version
- Pins critical dependency versions (torch, streamlit, keras)
- Defines entry points
- Makes the project installable as a package

### 4. A hardware compatibility matrix:

| Hardware | CPU | RAM | GPU | OS | Status | Notes |
|----------|-----|-----|-----|----|--------|-------|
| Judge's laptop | i5 10th gen | 8GB | None | Windows 11 | TEST IT | |
| Rural PHC laptop | i3 8th gen | 4GB | None | Ubuntu 22.04 | TEST IT | |
| MacBook Air M1 | Apple M1 | 8GB | Metal | macOS 14 | TEST IT | |
| Kaggle notebook | Xeon | 13GB | T4 x2 | Ubuntu | TEST IT | |
| Raspberry Pi 4 | ARM Cortex | 4GB | None | Raspberry Pi OS | TEST IT | |

### 5. Error handling for common failure modes:
- Model file missing → graceful fallback
- Camera not recognized → default thresholds
- No internet → offline mode confirmed
- Low memory → process optimization
- Unsupported image format → clear error message
- CUDA unavailable → CPU fallback confirmed
- Streamlit version mismatch → compatibility layer
