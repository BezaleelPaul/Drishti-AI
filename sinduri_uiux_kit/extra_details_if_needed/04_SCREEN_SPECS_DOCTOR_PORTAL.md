# 🖥️ 04. Screen Specifications: Tele-Ophthalmology Review Portal
## Desktop Web Interface (`1440 × 900 px`) for District Hospital Specialists

This is the interface used by Dr. Verma, the district ophthalmologist, who reviews referred high-risk cases sent from 50 rural PHCs.

---

### 1. Global Navigation Bar (`Height: 64px`, Background: `#0A2540` Dark Navy)
* **Left:** `Netra-AI District Tele-Review Station` | Badge: `Civil Hospital Tele-Ophthalmology Hub`
* **Center:** Triage Queue Filter:
  * `[ 🔴 Urgent Referrals (14) ]` `[ 🟠 Moderate (38) ]` `[ 🟢 Routine (122) ]` `[ All (174) ]`
* **Right:** Specialist Profile: `Dr. A. Verma, MS (Ophthalmology)` | `🔔 3 New Emergencies`

---

### 2. Patient Demographics & Upstream Risk Bar (`Height: 72px`, Surface: `#FFFFFF`, Border: `1px solid #E2E8F0`)
* **Patient:** `Ramesh Kumar` (Male, 54 yrs) | **ABHA ID:** `91-4521-8890-3321`
* **Origin:** `PHC Shirur (Ward 4)` | **Captured By:** `ASHA Sunita Bai` | **Camera:** `Forus 3nethra Handheld`
* **Clinical Biomarkers:** 
  * Diabetes: `12 yrs`
  * HbA1c: `8.8%` (Very High)
  * Blood Pressure: `145/92 mmHg`
* **Worst-Eye Rule Triage:** `OD (Right Eye): Severe DR` | `OS (Left Eye): Moderate DR`

---

### 3. Central 3-Way Synchronized Retinal Inspection Viewport (`Height: 520px`)
Divide the central canvas into 3 synchronized viewer panels:

```text
┌──────────────────────────────┬──────────────────────────────┬──────────────────────────────┐
│ PANEL 1: RAW HANDHELD FUNDUS │ PANEL 2: ADAPTIVE CLAHE (M.W) │ PANEL 3: VESSEL TREE + CSME  │
│                              │                              │                              │
│   (Original unenhanced       │   (MathWorks Requirement 1:  │   (MathWorks Requirement 2:  │
│    color fundus scan from    │    Adaptive CLAHE enhanced   │    Black-Hat morphological   │
│    rural field camera)       │    contrast in LAB space)    │    vessels + Grad-CAM)       │
│                              │                              │                              │
│   Badge: Raw RGB (512x512)   │   Badge: CLAHE Normalized    │   Badge: 13,495 Vessel Px    │
└──────────────────────────────┴──────────────────────────────┴──────────────────────────────┘
```

* **Controls Toolbar (Above panels):**
  * `[ Zoom: 100% / 200% / 400% ]` `[ Synchronized Pan 🔒 ]` `[ Grad-CAM Heatmap Toggle (On/Off) ]` `[ Invert Vessel Tree ]`

---

### 4. Specialist Decision & Action Console (`Bottom Bar / Right Drawer`)

#### A. AI Diagnosis vs. Doctor Override:
* **AI Predicted Grade:** `Grade 3 - Severe NPDR (Confidence: 94.2%)`
* **Grad-CAM Latency:** `0.10s (MathWorks constraint: <30s)`
* **Doctor Action Buttons:**
  * `✅ Confirm AI Grade 3` (Teal `#0D9488`)
  * `✏️ Doctor Override / Re-Grade` (Outline Button)

#### B. Clinical Triage Prescription (1-Click Actions):
* `[ 🏥 Urgent In-Person Laser Photocoagulation (<72 Hours) ]`
* `[ 💉 Anti-VEGF Intravitreal Therapy ]`
* `[ 📅 Tele-Followup in 90 Days ]`

#### C. Official Export & Sync:
* `📄 Download Hospital Dossier (ReportLab A4 PDF)`
* `🌐 Push to ABDM National Health Stack (HL7 FHIR R4)`
