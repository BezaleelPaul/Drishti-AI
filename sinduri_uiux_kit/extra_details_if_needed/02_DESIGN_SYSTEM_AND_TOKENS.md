# 🎨 02. Design System & Tokens
## Clinical HealthTech Visual Language (WCAG AAA Accessible)

Medical applications require **maximum clarity, immediate trust, and zero cognitive load**. In outdoor rural India, glare from sunlight makes low-contrast UI unusable. Follow these tokens strictly in Figma.

---

### 1. Color Palette (Create these as Figma Color Styles)

#### A. Primary Clinical Brand
* **Navy Deep (Authority & Trust):** `#0A2540`
* **Royal MedTech Blue (Interactive elements):** `#1A56DB` (Hover: `#1E429F`)
* **Medical Teal (Accent & AI highlights):** `#0D9488` (Light: `#CCFBF1`)

#### B. Semantic Triage Colors (Life-Critical for Doctors & Patients)
These represent the clinical Diabetic Retinopathy severity levels:

| Level & Meaning | Surface Tint (Background) | Border & Icon Color | Text / Accent Color |
| :--- | :--- | :--- | :--- |
| **Pass / Normal (No DR)** | `#F0FDF4` (Green 50) | `#86EFAC` (Green 300) | `#15803D` (Green 700) |
| **Mild DR (Annual Monitoring)** | `#F0FDFA` (Teal 50) | `#5EEAD4` (Teal 300) | `#0F766E` (Teal 700) |
| **Moderate DR (6-Month Review)** | `#FEFCE8` (Yellow 50) | `#FDE047` (Yellow 300) | `#A16207` (Yellow 700) |
| **Severe DR (30-Day Referral)** | `#FFF7ED` (Orange 50) | `#FDBA74` (Orange 300) | `#C2410C` (Orange 700) |
| **Proliferative DR / CSME (Urgent <72h)** | `#FEF2F2` (Red 50) | `#FCA5A5` (Red 300) | `#B91C1C` (Red 700) |
| **Quality Rejection (Blurry/Retake)** | `#FFFBEB` (Amber 50) | `#FCD34D` (Amber 300) | `#B45309` (Amber 700) |

#### C. Neutral Surfaces (Clean Clinical Backdrop)
* **Canvas Background:** `#F8FAFC` (Slate 50)
* **Card Surface:** `#FFFFFF` (Pure White)
* **Card Border:** `#E2E8F0` (Slate 200 - 1px solid)
* **Text Primary (Headings):** `#0F172A` (Slate 900)
* **Text Secondary (Labels/Subtitles):** `#475569` (Slate 600)
* **Text Muted (Placeholders):** `#94A3B8` (Slate 400)

---

### 2. Typography Scale (Use `Inter` or `Plus Jakarta Sans`)

In Figma, set up these Text Styles:

```text
Display 1 (Grade Verdict)    -> 32px / Bold (700)      / Line Height: 40px
Heading 1 (Screen Title)     -> 24px / SemiBold (600)  / Line Height: 32px
Heading 2 (Card Title)       -> 18px / SemiBold (600)  / Line Height: 24px
Body Large (Main Actions)    -> 16px / Medium (500)    / Line Height: 24px
Body Regular (Descriptions)  -> 14px / Regular (400)   / Line Height: 20px
Metric Number (Biomarkers)   -> 20px / Bold (700)      / Tabular Numerals
Caption / Badge              -> 12px / SemiBold (600)  / Line Height: 16px (Uppercase tracked +0.5px)
```

---

### 3. Shadows & Elevation
* **Card Rest:** `0px 1px 3px rgba(15, 23, 42, 0.08), 0px 1px 2px rgba(15, 23, 42, 0.04)`
* **Active / Hover / Modal:** `0px 10px 15px -3px rgba(15, 23, 42, 0.1), 0px 4px 6px -4px rgba(15, 23, 42, 0.05)`

---

### 4. Touch Targets & Accessibility (ASHA Field Rules)
1. **Minimum Touch Target:** No button or clickable icon smaller than **$48 \times 48\text{ px}$** ($56\text{ px}$ preferred for primary action buttons).
2. **Text Contrast:** Contrast ratio between text and card background must exceed **4.5:1** (AA standard) and ideally **7:1** (AAA standard).
3. **Double Coding:** Never use color alone to convey meaning! Always pair color with an icon (e.g., Red 🛑 + Alert triangle icon + "Urgent Referral" text).
