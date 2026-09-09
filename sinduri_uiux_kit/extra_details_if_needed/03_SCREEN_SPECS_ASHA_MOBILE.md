# 📱 03. Screen Specifications: ASHA Field Mobile Flow
## 5 Essential Screens on 8-Inch Tablet / Mobile Frame (`800 × 1280` or `390 × 844`)

These 5 screens represent the real-world workflow of an ASHA worker screening a rural diabetic patient in a primary health center.

---

### Screen 1: Fast Patient Intake & ABHA Check-in
* **Purpose:** Register the villager in $<20$ seconds without painful keyboard typing.
* **Header:**
  * Left: Government of India / National Health Mission logo + "Netra-AI Rural Triage".
  * Right: ASHA Profile ("Sunita Bai • PHC Shirur") + Offline Sync status icon (🟢 Online / 🟠 Syncing).
* **Card 1: Ayushman Bharat (ABHA) Verification:**
  * Large Button: `📷 Scan ABHA QR Code` (Primary Blue).
  * Or Manual Input: `14-digit ABHA Number` (e.g., `91-4521-8890-3321`).
* **Card 2: Quick Clinical Risk Factors (1-Tap Chips):**
  * Patient Name: `Ramesh Kumar` | Age: `54` | Sex: `Male`
  * Diabetes Duration: `[ <5 yrs ]` `[ 5-10 yrs ]` `[ >10 yrs (Selected) ]`
  * Last HbA1c: `8.8%` (High) | Systolic BP: `145 mmHg`
* **Bottom Action:**
  * Button: `Proceed to Retinal Scan →` (Full width, Height: 56px, Royal Blue `#1A56DB`).

---

### Screen 2: Retinal Capture Viewfinder & Camera Preset
* **Purpose:** Guide the ASHA worker to align the handheld camera with the patient's pupil.
* **Top Bar:**
  * Hardware Preset Dropdown: `📷 Forus 3nethra Classic (Handheld)` (Options: `Remidio FOP`, `Volk iNview`).
  * Eye Selector Segmented Control: `[ OD - Right Eye (Active) ]` `[ OS - Left Eye ]`
* **Center Viewport (Camera HUD):**
  * Live circular camera feed (drop in `assets/scenario_1_good.jpg` or `assets/real_clinical_fundus_patient1.jpg`).
  * Circular alignment reticle overlay (Dotted green target ring showing where optic disc and macula should sit).
  * Live status pill at bottom of circle: `🟢 Position Locked • Good Ambient Light`.
* **Bottom Capture Controls:**
  * Giant Circular Shutter Button (72px, White with Teal border).
  * Left: `Flash Toggle (Auto)`.
  * Right: `Gallery Upload` (for demo testing).

---

### Screen 3: Instant Quality Gate Verdict (Blur & Glare Check)
* **Purpose:** Prevent garbage-in-garbage-out. The AI verifies if the image is medically gradable in **0.12 seconds**.
* **Variant A (REJECTED / BLURRY - The Key Demo!):**
  * *Image:* Drop in `assets/scenario_2_bad.jpg`.
  * *Status Banner (Warning Amber `#FFFBEB` with `#B45309` border):*
    * Icon: ⚠️
    * Title: `Retake Required: Image Blurry & Underexposed`
    * Quality Score: `0.38 / 1.00 (Threshold: 0.65)`
  * *ASHA Alignment Guide Card:*
    * `1. Move camera 2 cm closer to eye.`
    * `2. Ask patient to look directly at the green internal fixation target.`
    * `3. Dim room light to allow natural pupil dilation.`
  * *Vernacular Voice Guidance Button:*
    * Large Audio Pill: `🔊 Hindi Audio: "कृपया कैमरा 2 सेमी पास लाएं"`
  * *Action Button:* `🔄 Retake Photograph` (High-contrast Amber `#D97706`).

* **Variant B (PASSED):**
  * *Status Banner (Success Green `#F0FDF4`):*
    * Icon: ✅ `Quality Verified (Score: 0.89) • Sharpness & Contrast Optimal`.
  * *Action Button:* `Run AI Diagnostic Triage →` (Royal Blue).

---

### Screen 4: Diagnostic Triage & Biomarker Card
* **Purpose:** Present the AI analysis clearly without confusing medical terminology.
* **Top Verdict Card (High Impact):**
  * *Status:* Red Crimson Alert `#FEF2F2` (if severe) or Green `#F0FDF4` (if normal).
  * *Severity Badge:* `GRADE 3: SEVERE NON-PROLIFERATIVE DR`
  * *Urgency:* `🔴 URGENT: Specialist Examination Required within 30 Days`
* **Retinal Inspection Split:**
  * Left Tile: Original Fundus scan.
  * Right Tile: Grad-CAM Explainability Heatmap (Shows red glowing zone highlighting microaneurysms and hemorrhages).
* **Extracted Biomarkers (Clean 2x2 Grid):**
  * Tile 1: `Vessel Density: 14.8%` (Normal: 12-16%)
  * Tile 2: `CSME Macular Edema: HIGH RISK (Ratio 1.42 > 1.20)`
  * Tile 3: `Hemorrhage Count: 18 detected`
  * Tile 4: `AI Latency: 0.10s (CPU Edge)`
* **Bottom Action:**
  * Button: `Generate Referral & Patient Slip →` (Full width, 56px).

---

### Screen 5: Referral Dispatch & Patient Action Hub
* **Purpose:** Ensure the patient actually gets care and doesn't get lost in the village.
* **Card 1: 1-Click SMS Referral to Patient Mobile:**
  * Mobile Input: `+91 98451 22340`
  * Preview SMS:
    > *"Ayushman Bharat Screening Alert: Ramesh Kumar, your eye scan at PHC Shirur indicates Severe Retinopathy with swelling risk. Please visit District Hospital Eye OPD before 20-Oct-2026. Ref ID: AB-DR-8891"*
  * Button: `📲 Send Free SMS Referral Slip`
* **Card 2: Printable Hospital Referral Slip (Bluetooth Thermal Printer):**
  * Shows mini barcode / QR code with ABHA ID + Dr. Signature space.
  * Button: `🖨️ Print 2-Inch Thermal Receipt`
* **Card 3: ABDM Digital Locker Export:**
  * Status: `✅ HL7 FHIR R4 DiagnosticReport Queued for District Hospital EMR`
* **Bottom Button:**
  * `Start Next Patient Screen ➕`
