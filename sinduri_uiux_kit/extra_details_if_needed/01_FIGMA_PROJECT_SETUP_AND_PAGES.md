# 📐 01. Figma Project Setup & Page Structure
## Professional Senior-Level Architecture for SIH 2026

To impress hackathon judges and design mentors, your Figma file should look like it was built by a Senior Product Designer at Google Health or Philips MedTech.

---

### 1. Canvas Pages Organization
In Figma's left sidebar, create these **6 distinct Pages**:

```text
📁 NETRA-AI DESIGN SYSTEM (Figma File)
├── 📄 01. Cover & Executive Summary     <- Thumbnail, SIH details, problem statement
├── 📄 02. Design Tokens & Foundations   <- Colors, typography, elevation, spacing grid
├── 📄 03. Component Library             <- Reusable atoms/molecules (Buttons, cards, badges)
├── 📄 04. ASHA Field Mobile Flow        <- 5 screens on 8-inch Android tablet / Phone frame
├── 📄 05. Tele-Ophthalmology Portal     <- Desktop 1440x900 doctor review console
└── 📄 06. Presentation & Mockups        <- High-res 3D perspective frames for slides
```

---

### 2. Device Frames to Select in Figma

#### A. Field Worker (ASHA) Interface:
* **Recommended Frame:** **Android Large** (`360 × 800 px`) or **iPad Mini / 8-inch Tablet** (`768 × 1024 px` or `800 × 1280 px`).
* *Why:* Rural ASHA workers typically carry standard government-issued 8-inch Android tablets (e.g., Samsung Galaxy Tab A7 Lite or Lenovo M8).
* *Orientation:* Portrait (`800 × 1280 px` or `390 × 844 px` iPhone 14/15 frame for mobile pitch).

#### B. Tele-Ophthalmologist Review Station:
* **Recommended Frame:** **Desktop 1440** (`1440 × 900 px`) or **MacBook Air** (`1280 × 832 px`).
* *Why:* Eye specialists at district hospitals review retinal scans on desktop monitors.

---

### 3. Layout Grid Settings

Set up these layout grids on your frames (`Shift + G` to toggle):

* **Mobile / Tablet (4 Columns):**
  * Columns: `4`
  * Margin: `16px` (or `24px` for tablet)
  * Gutter: `16px`
* **Desktop Portal (12 Columns):**
  * Columns: `12`
  * Margin: `64px`
  * Gutter: `24px`

---

### 4. Auto-Layout Standards (The Secret to Clean UI)
Never place text or buttons randomly on the canvas! Use Figma Auto-Layout (`Shift + A`):
* **Spacing Scale:** Strictly follow an **8-point grid** (`4px`, `8px`, `12px`, `16px`, `24px`, `32px`, `48px`).
* **Buttons:** 
  * Padding: Horizontal `24px`, Vertical `16px` (Ensures a touch height $\ge 48\text{px}$).
  * Corner Radius: `12px` (Modern, approachable, clinical).
* **Cards / Panels:**
  * Padding: `20px` internal padding.
  * Corner Radius: `16px`.
  * Background: Pure White (`#FFFFFF`) with subtle border (`1px solid #E2E8F0`).
