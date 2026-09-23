"""Generate the Drishti-AI SIH 2026 presentation deck."""

import os

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches, Pt

# --- Design tokens (Drishti clinical system) ---
NAVY = RGBColor(0x0A, 0x25, 0x40)
NAVY_MID = RGBColor(0x12, 0x3A, 0x5C)
NAVY_SOFT = RGBColor(0x1B, 0x4A, 0x6E)
TEAL = RGBColor(0x0D, 0x94, 0x88)
TEAL_DARK = RGBColor(0x0F, 0x76, 0x6E)
TEAL_LIGHT = RGBColor(0xCC, 0xFB, 0xF1)
TEAL_MINT = RGBColor(0xF0, 0xFD, 0xFA)
BLUE = RGBColor(0x1A, 0x56, 0xDB)
BLUE_SOFT = RGBColor(0xDB, 0xEA, 0xFE)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
CANVAS = RGBColor(0xF8, 0xFA, 0xFC)
SLATE_900 = RGBColor(0x0F, 0x17, 0x2A)
SLATE_700 = RGBColor(0x33, 0x41, 0x55)
SLATE_600 = RGBColor(0x47, 0x55, 0x69)
SLATE_400 = RGBColor(0x94, 0xA3, 0xB8)
SLATE_200 = RGBColor(0xE2, 0xE8, 0xF0)
SLATE_100 = RGBColor(0xF1, 0xF5, 0xF9)
GREEN = RGBColor(0x15, 0x80, 0x3D)
GREEN_BG = RGBColor(0xF0, 0xFD, 0xF4)
GREEN_BD = RGBColor(0x86, 0xEF, 0xAC)
AMBER = RGBColor(0xB4, 0x53, 0x09)
AMBER_BG = RGBColor(0xFF, 0xFB, 0xEB)
AMBER_BD = RGBColor(0xFC, 0xD3, 0x4D)
RED = RGBColor(0xB9, 0x1C, 0x1C)
RED_BG = RGBColor(0xFE, 0xF2, 0xF2)
RED_BD = RGBColor(0xFC, 0xA5, 0xA5)
ORANGE = RGBColor(0xC2, 0x41, 0x0C)
ORANGE_BG = RGBColor(0xFF, 0xF7, 0xED)
GOLD = RGBColor(0xD4, 0xA0, 0x17)

FONT = "Calibri"
FONT_DISPLAY = "Calibri"

W, H = 13.333, 7.5


def _set_run(run, text, size, bold=False, color=SLATE_900, italic=False, name=FONT):
    run.text = text
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color
    run.font.name = name


def add_rect(slide, x, y, w, h, fill, line=None, line_w=1.0, radius=None):
    kind = MSO_SHAPE.ROUNDED_RECTANGLE if radius is not None else MSO_SHAPE.RECTANGLE
    s = slide.shapes.add_shape(kind, Inches(x), Inches(y), Inches(w), Inches(h))
    s.fill.solid()
    s.fill.fore_color.rgb = fill
    if line is None:
        s.line.fill.background()
    else:
        s.line.color.rgb = line
        s.line.width = Pt(line_w)
    if radius is not None:
        try:
            s.adjustments[0] = radius
        except Exception:  # noqa: BLE001, S110 - optional PowerPoint styling
            pass
    s.shadow.inherit = False
    return s


def add_tb(slide, x, y, w, h, lines, anchor=MSO_ANCHOR.TOP):
    """lines: list of dicts {text, size, bold, color, align, italic, space_after}"""
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.auto_size = None
    try:
        tf._txBody.bodyPr.set("anchor", {MSO_ANCHOR.TOP: "t", MSO_ANCHOR.MIDDLE: "ctr", MSO_ANCHOR.BOTTOM: "b"}.get(anchor, "t"))
    except Exception:  # noqa: BLE001, S110 - optional PowerPoint styling
        pass
    for i, ln in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = ln.get("align", PP_ALIGN.LEFT)
        p.space_after = Pt(ln.get("space_after", 0))
        p.space_before = Pt(ln.get("space_before", 0))
        p.line_spacing = ln.get("line_spacing", 1.05)
        run = p.add_run()
        _set_run(
            run,
            ln.get("text", ""),
            ln.get("size", 14),
            ln.get("bold", False),
            ln.get("color", SLATE_900),
            ln.get("italic", False),
            ln.get("font", FONT),
        )
    return box


def add_notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


def set_slide_bg(slide, color):
    bg = slide.background
    fill = bg.fill
    fill.solid()
    fill.fore_color.rgb = color


def footer(slide, page, total=14):
    add_rect(slide, 0, 7.28, W, 0.22, NAVY)
    add_tb(
        slide, 0.45, 7.28, 9.5, 0.22,
        [{"text": "Drishti-AI  ·  SIH26038  ·  MathWorks  ·  Software Prototype Track",
          "size": 10, "color": RGBColor(0xCB, 0xD5, 0xE1), "bold": False}],
        anchor=MSO_ANCHOR.MIDDLE,
    )
    add_tb(
        slide, 11.4, 7.28, 1.5, 0.22,
        [{"text": f"{page:02d}  /  {total:02d}", "size": 10, "color": TEAL_LIGHT,
          "bold": True, "align": PP_ALIGN.RIGHT}],
        anchor=MSO_ANCHOR.MIDDLE,
    )


def header_bar(slide, kicker, title, subtitle=None):
    add_rect(slide, 0, 0, W, 1.22, NAVY)
    add_rect(slide, 0, 0, 0.14, 1.22, TEAL)
    add_tb(slide, 0.45, 0.10, 12.4, 0.28, [
        {"text": kicker.upper(), "size": 11, "bold": True, "color": TEAL, "space_after": 0}
    ])
    add_tb(slide, 0.45, 0.34, 12.4, 0.46, [
        {"text": title, "size": 26, "bold": True, "color": WHITE}
    ])
    if subtitle:
        add_tb(slide, 0.45, 0.82, 12.4, 0.32, [
            {"text": subtitle, "size": 13, "color": RGBColor(0xCB, 0xD5, 0xE1)}
        ])


def card(slide, x, y, w, h, fill=WHITE, line=SLATE_200, radius=0.08):
    return add_rect(slide, x, y, w, h, fill, line=line, line_w=1.0, radius=radius)


def blank():
    return prs.slides.add_slide(prs.slide_layouts[6])


# ---------------------------------------------------------------------------
prs = Presentation()
prs.slide_width = Inches(W)
prs.slide_height = Inches(H)


# ============================== SLIDE 1: TITLE ==============================
s = blank()
set_slide_bg(s, NAVY)
add_rect(s, 0, 0, 0.18, H, TEAL)
add_rect(s, 0, 6.95, W, 0.55, RGBColor(0x07, 0x1A, 0x2E))

add_tb(s, 0.70, 0.42, 12, 0.32, [
    {"text": "SMART INDIA HACKATHON  2026   ·   SOFTWARE PROTOTYPE TRACK",
     "size": 13, "bold": True, "color": TEAL}
])
add_tb(s, 0.70, 0.92, 12, 0.28, [
    {"text": "Problem Statement  SIH26038    ·    Organisation  MathWorks    ·    Theme  MedTech / HealthTech",
     "size": 14, "color": RGBColor(0x94, 0xA3, 0xB8)}
])
add_tb(s, 0.70, 1.70, 12, 1.15, [
    {"text": "Drishti-AI", "size": 60, "bold": True, "color": WHITE, "font": FONT_DISPLAY}
])
add_tb(s, 0.70, 2.85, 11.8, 0.90, [
    {"text": "Explainable dual-stage diabetic retinopathy screening",
     "size": 24, "color": TEAL_LIGHT, "space_after": 4},
    {"text": "for rural Primary Health Centres — offline, on the edge, with the AI allowed to abstain.",
     "size": 18, "color": RGBColor(0xCB, 0xD5, 0xE1)}
])

# metric chips
chips = [
    ("100%", "offline"),
    ("~1.4 s", "end-to-end screening"),
    ("0%", "forced grades on ungradables"),
    ("99.1%", "bandwidth saved"),
]
for i, (n, l) in enumerate(chips):
    x = 0.70 + i * 3.05
    add_rect(s, x, 4.15, 2.85, 1.15, NAVY_MID, radius=0.08)
    add_rect(s, x, 4.15, 2.85, 0.07, TEAL)
    add_tb(s, x + 0.18, 4.32, 2.5, 0.50, [{"text": n, "size": 26, "bold": True, "color": WHITE}])
    add_tb(s, x + 0.18, 4.82, 2.5, 0.32, [{"text": l, "size": 13, "color": TEAL_LIGHT}])

add_tb(s, 0.70, 5.55, 12, 0.70, [
    {"text": "Bezaleel   ·   Madhu   ·   Akshay   ·   Adithya   ·   Sinduri   ·   Megha",
     "size": 16, "bold": True, "color": WHITE, "space_after": 4},
    {"text": "Team Lead  ·  Clinical  ·  Deep Learning  ·  Safety  ·  ASHA UX  ·  Clinical UX",
     "size": 13, "color": SLATE_400}
])
add_tb(s, 0.70, 7.02, 12, 0.32, [
    {"text": "Locked to the approved clinical decision flow  ·  Honest scientific guardrails  ·  Built for the last mile, not the lab",
     "size": 12, "color": RGBColor(0x94, 0xA3, 0xB8)}
])
add_notes(s, "Open with the name, the problem ID, and the one-line thesis: we are not inventing 5-class DR classification — we are making it work in a rural PHC.")


# ============================== SLIDE 2: PROBLEM ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "01  —  The clinical reality", "India cannot screen diabetes-related blindness with specialists alone.",
           "77 million diabetic adults. One ophthalmologist per 100,000 rural citizens. Early triage can save 90% of sight.")

stats = [
    ("77M+", "diabetic adults in India", "DR is the leading cause of preventable adult blindness."),
    ("1 : 100k", "rural ophthalmologist ratio", "Universal hospital screening is mathematically impossible."),
    ("25–35%", "ungradable field captures", "Handheld, non-mydriatic cameras in camps and PHCs."),
    ("70%+", "screened eyes are healthy", "Without triage, district hospitals drown in false referrals."),
]
for i, (n, t, d) in enumerate(stats):
    x = 0.40 + (i % 4) * 3.20
    y = 1.50
    card(s, x, y, 3.05, 2.55, WHITE)
    add_rect(s, x, y, 3.05, 0.08, TEAL if i % 2 == 0 else BLUE)
    add_tb(s, x + 0.18, y + 0.28, 2.7, 0.70, [{"text": n, "size": 32, "bold": True, "color": NAVY}])
    add_tb(s, x + 0.18, y + 1.00, 2.7, 0.55, [{"text": t, "size": 14, "bold": True, "color": TEAL_DARK}])
    add_tb(s, x + 0.18, y + 1.55, 2.7, 0.80, [{"text": d, "size": 13, "color": SLATE_600}])

card(s, 0.40, 4.25, 12.55, 2.80, WHITE)
add_tb(s, 0.65, 4.42, 12.1, 0.40, [
    {"text": "The last-mile gap — not a missing model, a missing operating system for rural screening",
     "size": 16, "bold": True, "color": NAVY}
])
bullets = [
    "Community camps, mobile vans, and PHCs use ₹15,000 handheld fundus attachments (Remidio, Forus 3Nethra, Volk iNview) under undilated pupils.",
    "Hospital-lab systems (Google Health ARDA, IDx-DR, EyeArt) proved 5-class grading on Zeiss/Topcon cameras and cloud GPUs. They fail when power, bandwidth, operators, and optics change.",
    "A rural PHC cannot upload 5–15 MB raw images per eye over 2G/3G, cannot wait on cloud GPUs, and cannot staff a retinal specialist on every screening day.",
]
y = 4.90
for b in bullets:
    add_tb(s, 0.75, y, 11.9, 0.55, [{"text": "▸  " + b, "size": 14, "color": SLATE_700}])
    y += 0.58
footer(s, 2)
add_notes(s, "Spend 90 seconds here. The number that should land is 1 ophthalmologist per 100,000. Then: the problem is not inventing classification — it is getting screening to run where the patients actually are.")


# ============================== SLIDE 3: FAILURE MODES ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "02  —  Why laboratory AI fails in the field",
           "Four deployment failure modes that a hospital model never sees.",
           "Prior work solved grading under curated conditions. Rural India fails on garbage-in, bandwidth, black-box labels, and specialist overload.")

modes = [
    (RED, "01", "Garbage-in, garbage-out",
     "Up to 25–35% of camp captures are motion-blurred, poorly lit, occluded, or not even fundus. A classifier still emits an authoritative grade — missed proliferative disease, or a flood of false referrals."),
    (BLUE, "02", "Cloud & bandwidth choke",
     "5–15 MB uncompressed images per eye over 4G/5G is a hospital assumption. Intermittent 2G/3G and power cuts turn cloud inference into camp backlogs."),
    (AMBER, "03", "Label without a biomarker",
     "“Grade 2: Moderate NPDR” does not tell a rural physician whether the macula is in danger. Clinicians need macular distance (CSME risk) and visual evidence before spending a referral."),
    (TEAL, "04", "District-scale overload",
     "Without local triage, every screened patient is sent onward. Specialists drown in healthy eyes that make up 70%+ of screened populations."),
]
for i, (c, n, t, d) in enumerate(modes):
    x = 0.40 + (i % 2) * 6.45
    y = 1.50 + (i // 2) * 2.70
    card(s, x, y, 6.25, 2.50, WHITE)
    add_rect(s, x, y, 0.12, 2.50, c)
    add_tb(s, x + 0.40, y + 0.22, 5.6, 0.36, [{"text": n, "size": 12, "bold": True, "color": c}])
    add_tb(s, x + 0.40, y + 0.55, 5.6, 0.45, [{"text": t, "size": 18, "bold": True, "color": NAVY}])
    add_tb(s, x + 0.40, y + 1.10, 5.6, 1.15, [{"text": d, "size": 14, "color": SLATE_700}])
footer(s, 3)
add_notes(s, "The aha: a standard classifier forced to grade every capture is dangerous. That is the failure mode we designed against.")


# ============================== SLIDE 4: THESIS ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "03  —  What we are actually building",
           "We did not invent 5-class DR grading. We operationalised it for rural India.",
           "SIH26038 · MathWorks  —  last-mile edge screening, not another hospital notebook.")

add_rect(s, 0.40, 1.50, 12.55, 1.70, NAVY, radius=0.06)
add_tb(s, 0.70, 1.70, 12.0, 1.35, [
    {"text": "“The AI must know when it cannot answer.”", "size": 22, "bold": True, "color": WHITE, "space_after": 8},
    {"text": "An ungradable retinal photograph must never be silently forced into a disease prediction. Quality first. Abstention second. Grading only on reliable original pixels.",
     "size": 15, "color": TEAL_LIGHT}
])

# two columns: claim / not claim
card(s, 0.40, 3.42, 6.25, 3.60, WHITE)
add_rect(s, 0.40, 3.42, 6.25, 0.50, TEAL)
add_tb(s, 0.60, 3.50, 5.9, 0.38, [{"text": "OUR CONTRIBUTION", "size": 13, "bold": True, "color": WHITE}])
claims = [
    "Quality gate before grading, tuned for handheld rural optics",
    "100% offline pipeline on a ₹15,000-class laptop CPU",
    "Quantitative CSME risk from OD–fovea geometry",
    "District-scale triage that cuts telemetry 99.1%",
    "Bilingual ASHA workflow + ABDM FHIR reporting",
]
yy = 4.08
for c in claims:
    add_tb(s, 0.65, yy, 5.8, 0.48, [{"text": "●   " + c, "size": 13, "color": SLATE_700}])
    yy += 0.52

card(s, 6.85, 3.42, 6.10, 3.60, WHITE)
add_rect(s, 6.85, 3.42, 6.10, 0.50, NAVY)
add_tb(s, 7.05, 3.50, 5.7, 0.38, [{"text": "HONEST BOUNDARIES  —  WHAT WE ARE NOT CLAIMING", "size": 12, "bold": True, "color": WHITE}])
nots = [
    "We did not invent image-quality gating (ARDA, IDx-DR, EyeArt already do it).",
    "We are not a certified medical device (CDSCO Class B/C still required).",
    "Grad-CAM++ is attention evidence, not automated lesion segmentation.",
    "High-risk, low-confidence, and ungradable cases always go to a human.",
    "We do not rewrite pixels before Model 2. Original photograph only.",
]
yy = 4.08
for c in nots:
    add_tb(s, 7.10, yy, 5.65, 0.52, [{"text": "○   " + c, "size": 13, "color": SLATE_700}])
    yy += 0.52
footer(s, 4)
add_notes(s, "This slide wins trust. Judges have seen 50 ‘99% accurate CNN’ decks. Say what we are not claiming, then what we uniquely operationalise.")


# ============================== SLIDE 5: FOUR PILLARS ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "04  —  Four design questions, in priority order",
           "Every architecture decision answers one of these. Nothing else.",
           "Sustainability  ·  Availability  ·  Accessibility  ·  Platform independence")

pillars = [
    ("01", "Will it keep running here?", "Sustainability", TEAL,
     "Zero cloud compute bill. Inference on-device. Reject ungradable images before wasting cycles. Designed for existing ₹15k laptops — no forced hardware refresh."),
    ("02", "Can everyone reach it?", "Availability", BLUE,
     "Offline-first screening. Opportunistic sync. 2G/3G packets. 20 PHCs + 5 vans × 100k patients simulated. Specialist load from ~4 doctors down to ~1 tele-reviewer per 100k."),
    ("03", "Can everyone use it?", "Accessibility", AMBER,
     "ASHA/ANM operated. Plain-language recapture. Hindi + English reports, English audio prompts. Commodity cameras. Clear / Review / Urgent at a glance, plus ICDR grades."),
    ("04", "Will it run on what they have?", "Independence", RED,
     "Open-source. Windows, macOS, Linux, Docker. HL7 FHIR R4, SNOMED CT, LOINC, ABDM. Sensor-agnostic: DICOM, JPEG, PNG. No camera SDK lock-in."),
]
for i, (n, q, name, c, d) in enumerate(pillars):
    x = 0.40 + i * 3.20
    add_rect(s, x, 1.50, 3.05, 5.50, WHITE, line=SLATE_200, radius=0.08)
    add_rect(s, x, 1.50, 3.05, 0.10, c)
    add_tb(s, x + 0.18, 1.75, 2.70, 0.30, [{"text": n, "size": 12, "bold": True, "color": c}])
    add_tb(s, x + 0.18, 2.10, 2.70, 0.35, [{"text": name.upper(), "size": 12, "bold": True, "color": SLATE_400}])
    add_tb(s, x + 0.18, 2.50, 2.70, 1.35, [{"text": q, "size": 18, "bold": True, "color": NAVY}])
    add_tb(s, x + 0.18, 4.00, 2.70, 2.60, [{"text": d, "size": 13, "color": SLATE_700}])
footer(s, 5)
add_notes(s, "Walk the four questions in order. Judges should hear that cloud-first was rejected on purpose.")


# ============================== SLIDE 6: PIPELINE ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "05  —  Locked clinical decision flow",
           "Quality is the first clinical decision. Grading is the second.",
           "Non-destructive. Bounded recapture. Two-tier human review. High-risk always escalates.")

steps = [
    ("1", "Capture", "Handheld fundus\n₹15k attachment"),
    ("2", "Quality", "Model 1 gate\nGood / Mid / Bad"),
    ("3", "Grade", "Model 2 · 5-class\nonly if reliable"),
    ("4", "Explain", "Grad-CAM++\n+ CSME distance"),
    ("5", "Act", "Report · FHIR\nrefer or recapture"),
]
for i, (n, t, d) in enumerate(steps):
    x = 0.35 + i * 2.60
    shp = s.shapes.add_shape(MSO_SHAPE.CHEVRON, Inches(x), Inches(1.48), Inches(2.50), Inches(0.85))
    shp.fill.solid()
    shp.fill.fore_color.rgb = NAVY if i != 1 else TEAL
    shp.line.fill.background()
    shp.shadow.inherit = False
    tf = shp.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    run = p.add_run()
    _set_run(run, f"{n}   {t}", 14, True, WHITE)
    add_tb(s, x, 2.40, 2.45, 0.70, [{"text": d, "size": 12, "color": SLATE_600, "align": PP_ALIGN.CENTER}])

# three quality outcomes
outcomes = [
    (GREEN, GREEN_BG, GREEN_BD, "GOOD", "Reliable original image → Model 2. Pixel-for-pixel the same photograph that passed the gate. No CLAHE, no sharpening, no generative filters."),
    (AMBER, AMBER_BG, AMBER_BD, "BORDERLINE", "Reassessment with stricter thresholds. Cleared → Model 2. Still unreliable → treat as Bad. Never silently upgraded."),
    (RED, RED_BG, RED_BD, "BAD", "Recapture with a specific reason (blur, illumination, FOV). Hard cap of 2 retries, then operator-level human review. DR grade: not generated."),
]
for i, (c, bg, bd, t, d) in enumerate(outcomes):
    x = 0.40 + i * 4.25
    add_rect(s, x, 3.20, 4.05, 2.55, bg, line=bd, radius=0.08)
    add_tb(s, x + 0.20, 3.35, 3.65, 0.40, [{"text": t, "size": 16, "bold": True, "color": c}])
    add_tb(s, x + 0.20, 3.80, 3.65, 1.75, [{"text": d, "size": 13, "color": SLATE_700}])

add_tb(s, 0.45, 5.90, 12.4, 1.10, [
    {"text": "After a reliable grade: confidence check  →  Grad-CAM heatmap  →  bilingual PDF + FHIR R4.  Low confidence (<60%) or Grade 3/4  →  ophthalmologist over-read.  Operator review ≠ clinical review.",
     "size": 14, "color": SLATE_700}
])
footer(s, 6)
add_notes(s, "This is the locked flow. Emphasise: Bad images produce ‘DR Prediction: Not generated’. That is the product.")


# ============================== SLIDE 7: MODEL 1 ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "06  —  Model 1  ·  Image quality gate",
           "Abstain before you grade. Then tell the ASHA worker exactly what to fix.",
           "MathWorks Req 1  ·  blur · illumination · contrast · FOV  ·  biological defect attribution")

left_items = [
    ("Blur / focus", "Laplacian variance & multi-scale focus gradients. Motion vs defocus."),
    ("Illumination", "Underexposure, hotspots, corneal reflection uniformity."),
    ("Contrast", "Vessel-to-background contrast; ungradable if vessels vanish."),
    ("Field of view", "Dynamic circular ROI coverage — is enough retina present?"),
    ("Defect source", "Operator error (shake, lid) vs patient pathology (cataract, small pupil)."),
]
card(s, 0.40, 1.48, 7.40, 5.52, WHITE)
add_tb(s, 0.60, 1.62, 7.0, 0.36, [{"text": "WHAT THE GATE MEASURES", "size": 12, "bold": True, "color": TEAL}])
for i, (t, d) in enumerate(left_items):
    y = 2.08 + i * 0.92
    add_rect(s, 0.65, y, 0.12, 0.70, TEAL if i % 2 == 0 else BLUE, radius=0.5)
    add_tb(s, 0.95, y - 0.02, 6.55, 0.32, [{"text": t, "size": 15, "bold": True, "color": NAVY}])
    add_tb(s, 0.95, y + 0.30, 6.55, 0.42, [{"text": d, "size": 13, "color": SLATE_600}])

card(s, 8.00, 1.48, 4.95, 5.52, NAVY)
add_tb(s, 8.25, 1.70, 4.50, 0.40, [{"text": "OPERATOR FEEDBACK", "size": 12, "bold": True, "color": TEAL}])
add_tb(s, 8.25, 2.15, 4.50, 1.40, [
    {"text": "Not “image quality low”.", "size": 16, "bold": True, "color": WHITE, "space_after": 8},
    {"text": "Actionable, bilingual, audio-capable prompts for ASHA/ANM staff.",
     "size": 13, "color": RGBColor(0xCB, 0xD5, 0xE1)}
])
prompts = [
    "“Blur detected — hold the camera steady.”",
    "“Too dark — move closer to the light.”",
    "“Eyelid covering the view — ask the patient to open wide.”",
    "Cap: 2 recaptures, then human review.",
]
yy = 3.60
for p in prompts:
    add_tb(s, 8.25, yy, 4.50, 0.70, [{"text": p, "size": 13, "color": TEAL_LIGHT}])
    yy += 0.72
footer(s, 7)
add_notes(s, "Demo cue: show a blurry image rejected with a recapture reason. Contrast with a naive classifier that would have graded it.")


# ============================== SLIDE 8: MODEL 2 + XAI ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "07  —  Model 2, explainability & biomarkers",
           "Grade only reliable images. Show why. Measure the macula.",
           "MathWorks Req 2–4  ·  EfficientNetB0  ·  Grad-CAM++  ·  OD / fovea / vessels")

# grades strip
grades = [
    ("0", "No DR", GREEN, GREEN_BG),
    ("1", "Mild NPDR", TEAL, TEAL_MINT),
    ("2", "Moderate", GOLD, RGBColor(0xFE, 0xFC, 0xE8)),
    ("3", "Severe NPDR", ORANGE, ORANGE_BG),
    ("4", "Proliferative", RED, RED_BG),
]
for i, (n, t, c, bg) in enumerate(grades):
    x = 0.40 + i * 2.55
    add_rect(s, x, 1.48, 2.42, 0.85, bg, line=c, radius=0.08)
    add_tb(s, x + 0.12, 1.54, 2.18, 0.32, [{"text": f"GRADE  {n}", "size": 11, "bold": True, "color": c, "align": PP_ALIGN.CENTER}])
    add_tb(s, x + 0.12, 1.84, 2.18, 0.36, [{"text": t, "size": 14, "bold": True, "color": NAVY, "align": PP_ALIGN.CENTER}])

cols = [
    ("CLASSIFIER", [
        "EfficientNetB0 · 33.4 MB · APTOS 2019",
        "5-class ICDR severity, referable ≥ Grade 2",
        "~1.4 s end-to-end on Intel i3 / Ryzen 3, 4 GB RAM",
        "Softmax margin <60% → specialist review",
        "Grade 3 / 4 always flagged, regardless of confidence",
    ]),
    ("GRAD-CAM++", [
        "True gradient backprop through final conv maps",
        "Higher-order derivatives for dispersed micro-lesions",
        "<1.2 s on CPU  (MathWorks bound: 30 s)",
        "Attention heatmap — not lesion segmentation",
        "Overlaid on the original fundus for audit",
    ]),
    ("STRUCTURE / CSME", [
        "Optic disc: intensity + morphological opening",
        "Fovea: macular depression ~2.5 OD diameters temporal",
        "Vessels: top-hat + adaptive Otsu caliber",
        "Euclidean OD–fovea distance → CSME risk",
        "MA / exudate candidates as review overlays",
    ]),
]
for i, (title, items) in enumerate(cols):
    x = 0.40 + i * 4.25
    card(s, x, 2.52, 4.05, 4.48, WHITE)
    add_rect(s, x, 2.52, 4.05, 0.48, NAVY)
    add_tb(s, x + 0.18, 2.58, 3.70, 0.36, [{"text": title, "size": 13, "bold": True, "color": WHITE}])
    yy = 3.18
    for it in items:
        add_tb(s, x + 0.22, yy, 3.65, 0.68, [{"text": "▸  " + it, "size": 13, "color": SLATE_700}])
        yy += 0.70
footer(s, 8)
add_notes(s, "Akshay’s slide. Why EfficientNetB0: parameter-efficient, 33 MB, CPU-real. Why Grad-CAM++: dispersed lesions. Honest: heatmap ≠ segmentation.")


# ============================== SLIDE 9: SAFETY ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "08  —  Non-negotiable safety rules  (enforced in code)",
           "These are not slideware. They live in the router.",
           "Section 3 / 5 / 7 / 9 / 18 / 20  ·  two-tier human review")

rules = [
    ("01", "Non-destructive processing",
     "No runtime enhancement, CLAHE, sharpening, or generative filters before prediction. The image that reaches Model 2 is pixel-for-pixel the retinal photograph that reached Model 1."),
    ("02", "Abstention on unreliable images",
     "No Bad or still-unreliable image is handed to Model 2. Output is “DR Prediction: Not generated” plus a specific recapture reason code."),
    ("03", "Bounded recaptures",
     "Hard cap of 2 recaptures per patient session. Hitting the cap force-escalates to operator-level human review. No infinite retry loops in a camp."),
    ("04", "Mandatory high-risk override",
     "Grade 3 (Severe NPDR) and Grade 4 (Proliferative DR) are always flagged for ophthalmologist over-read, even at 99% model confidence."),
    ("05", "Two-tier human review",
     "Operator-level = camera, lighting, recapture. Clinical-level = diagnosis, referral urgency. The system never confuses a bad photo with a bad retina."),
]
for i, (n, t, d) in enumerate(rules):
    y = 1.46 + i * 1.10
    add_rect(s, 0.40, y, 12.55, 1.00, WHITE, line=SLATE_200, radius=0.06)
    add_rect(s, 0.40, y, 1.05, 1.00, NAVY)
    add_tb(s, 0.40, y + 0.28, 1.05, 0.44, [{"text": n, "size": 18, "bold": True, "color": TEAL, "align": PP_ALIGN.CENTER}])
    add_tb(s, 1.65, y + 0.10, 10.9, 0.34, [{"text": t, "size": 15, "bold": True, "color": NAVY}])
    add_tb(s, 1.65, y + 0.46, 10.9, 0.46, [{"text": d, "size": 13, "color": SLATE_600}])
footer(s, 9)
add_notes(s, "Read rule 02 and 04 aloud. They are the regulatory posture: human-in-the-loop, abstain-and-escalate, not a diagnostic device claiming autonomy.")


# ============================== SLIDE 10: EVIDENCE ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "09  —  Experimental evidence",
           "The gate is not a slogan. It changes what patients are told.",
           "150-image A/B/C benchmark  ·  0% forced prediction on ungradables  ·  full unit + integration suite")

# table-like rows
headers = ["METRIC", "ARM A  ·  NO GATE", "ARM B/C  ·  DRISHTI-AI", "WHY IT MATTERS"]
add_rect(s, 0.40, 1.48, 12.55, 0.48, NAVY)
xs = [0.50, 3.55, 6.70, 9.70]
ws = [3.0, 3.05, 2.90, 3.05]
for i, h in enumerate(headers):
    add_tb(s, xs[i], 1.54, ws[i], 0.36, [{"text": h, "size": 11, "bold": True, "color": TEAL_LIGHT}])

rows = [
    ("Forced predictions on ungradable images", "100%", "0%", "No fake grades on blur / garbage"),
    ("Referable DR specificity (reliable images)", "Unreliable", "91.6%", "Stops flooding district hospitals"),
    ("Screening recapture / abstention", "0%  (blind)", "20.7%", "Bounded field overhead, under 20% target"),
    ("Human review escalation", "0%  (silent fail)", "75.3%", "Ambiguity is surfaced, not buried"),
    ("Test suites (unit / integration / edge)", "—", "7 suites, clean", "Good / Bad / Borderline paths locked"),
]
for r, row in enumerate(rows):
    y = 2.02 + r * 0.78
    bg = WHITE if r % 2 == 0 else SLATE_100
    add_rect(s, 0.40, y, 12.55, 0.78, bg)
    cols_c = [NAVY, RED if r == 0 else SLATE_700, TEAL_DARK if r == 0 else NAVY, SLATE_600]
    bolds = [True, True, True, False]
    for i, val in enumerate(row):
        add_tb(s, xs[i], y + 0.20, ws[i], 0.42, [{"text": val, "size": 13, "bold": bolds[i], "color": cols_c[i]}])

add_tb(s, 0.45, 6.05, 12.4, 0.95, [
    {"text": "Arm A is the standard hackathon classifier: 100% of degraded images still receive a clinical-looking grade. Drishti-AI leaks 0%. That is the safety metric we will defend.",
     "size": 14, "color": SLATE_700}
])
footer(s, 10)
add_notes(s, "Adithya’s slide. Lead with 100% vs 0%. Do not oversell the 11.1% sensitivity number from the brief if asked — report CIs honestly and point to the safety metric.")


# ============================== SLIDE 11: SCALE ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "10  —  District-scale telemedicine  (MathWorks Req 5)",
           "Filter at the edge. Uplink only what a specialist must see.",
           "MATLAB / Simulink discrete-event queue  ·  100,000 patients / year  ·  20 PHCs + 5 vans  ·  1 district hospital")

big = [
    ("99.1%", "telemetry cut", "439.9 GB raw fundus  →  3.8 GB flagged cases + metadata"),
    ("~4 → ~1", "tele-reviewers / 100k", "Specialist bottleneck broken without hiding disease"),
    ("~1.2 s", "on-site turnaround", "vs ~1.9 min cloud-only round trip per patient"),
]
for i, (n, t, d) in enumerate(big):
    x = 0.40 + i * 4.25
    add_rect(s, x, 1.50, 4.05, 2.35, NAVY, radius=0.08)
    add_tb(s, x + 0.22, 1.70, 3.65, 0.70, [{"text": n, "size": 32, "bold": True, "color": TEAL}])
    add_tb(s, x + 0.22, 2.42, 3.65, 0.36, [{"text": t.upper(), "size": 12, "bold": True, "color": WHITE}])
    add_tb(s, x + 0.22, 2.82, 3.65, 0.75, [{"text": d, "size": 13, "color": RGBColor(0xCB, 0xD5, 0xE1)}])

card(s, 0.40, 4.08, 12.55, 2.92, WHITE)
add_tb(s, 0.65, 4.24, 12.1, 0.36, [{"text": "WHAT THE SIMULINK MODEL ACTUALLY SIMULATES", "size": 13, "bold": True, "color": TEAL}])
bits = [
    ("M/M/c queues", "Patient arrivals, edge inference, tele-ophthalmology uplink as a discrete-event system — not a static spreadsheet."),
    ("Local processing", "Only referable, low-confidence, high-risk, and recapture-exhausted cases leave the PHC."),
    ("Capacity proof", "Workload drops from 100,000 raw cases to ~16,100 triage cases/year (~62/day) — feasible for a single tele-reviewer."),
    ("Hostile networks", "Lightweight compressed packets remain viable on intermittent 2G/3G. Screening never waits on the WAN."),
]
for i, (t, d) in enumerate(bits):
    x = 0.65 + (i % 2) * 6.15
    y = 4.72 + (i // 2) * 1.00
    add_tb(s, x, y, 5.9, 0.28, [{"text": t, "size": 14, "bold": True, "color": NAVY}])
    add_tb(s, x, y + 0.32, 5.9, 0.55, [{"text": d, "size": 12, "color": SLATE_600}])
footer(s, 11)
add_notes(s, "Akshay/Adithya. 99.1% is the headline. Explain it as ‘we do not upload healthy eyes and ungradable pixels’.")


# ============================== SLIDE 12: DEPLOYMENT ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "11  —  Built for the field, not the demo booth",
           "Offline. Commodity hardware. Frontline UX. National digital health rails.",
           "The Flutter app is how judges interact. The product is everything that works outside a hospital.")

blocks = [
    (TEAL, "EDGE & OFFLINE",
     ["Zero runtime API calls or weight downloads",
      "Intel i3 / Ryzen 3, 4 GB RAM target",
      "Windows · macOS (Intel & Apple Silicon) · Linux · Docker",
      "One-command judge path: docker compose up"]),
    (BLUE, "HARDWARE AGNOSTIC",
     ["₹15,000 handheld fundus class (Remidio, Forus, Volk)",
      "No proprietary camera SDK",
      "DICOM / JPEG / PNG ingest",
      "Sensor-agnostic preprocessing"]),
    (AMBER, "ASHA → DOCTOR UX",
     ["Low-cognitive-load recapture HUD",
      "Hindi + English; Tamil/Telugu/Kannada roadmap",
      "Clear / Review / Urgent + ICDR grade",
      "Specialist console: Grad-CAM + CSME overlay"]),
    (NAVY, "INTEROPERABILITY",
     ["HL7 FHIR R4 · SNOMED CT · LOINC",
      "Ayushman Bharat Digital Mission aligned",
      "Bilingual PDF screening dossier",
      "DPDP-aware: no unencrypted PHI on the open WAN"]),
]
for i, (c, t, items) in enumerate(blocks):
    x = 0.40 + (i % 2) * 6.45
    y = 1.48 + (i // 2) * 2.70
    card(s, x, y, 6.25, 2.52, WHITE)
    add_rect(s, x, y, 0.12, 2.52, c)
    add_tb(s, x + 0.38, y + 0.16, 5.65, 0.36, [{"text": t, "size": 14, "bold": True, "color": c}])
    yy = y + 0.58
    for it in items:
        add_tb(s, x + 0.38, yy, 5.65, 0.42, [{"text": "▸  " + it, "size": 13, "color": SLATE_700}])
        yy += 0.42
footer(s, 12)
add_notes(s, "Sinduri/Megha/Bezaleel. Mention bilingual audio for blur. Mention ABDM so it is a national-systems pitch, not a model pitch.")


# ============================== SLIDE 13: TEAM ==============================
s = blank()
set_slide_bg(s, CANVAS)
header_bar(s, "12  —  Who builds what",
           "Six owners. Seven modules. One locked decision flow.",
           "No orphan components — every module has a named lead and a deliverable.")

team = [
    ("Bezaleel", "Team Lead  ·  Full-Stack",
     "Decision router, Streamlit, FastAPI, Docker, cross-platform zero-config."),
    ("Madhu", "Clinical Lead  ·  Biomed",
     "ICMR 2024 risk engine, OD/fovea CSME distance, clinical report validation."),
    ("Akshay", "Deep Learning  ·  Ops",
     "EfficientNetB0, Grad-CAM++, MATLAB/Simulink 100k-patient queueing model."),
    ("Adithya", "Safety  ·  Verification",
     "150-sample benchmark, 0% forced-prediction proof, edge-case hardening."),
    ("Sinduri", "UX  ·  ASHA field",
     "Mobile workflow, recapture HUD, Hindi audio prompts, Figma system."),
    ("Megha", "UX  ·  Doctor console",
     "Tele-ophthalmology workbench, Grad-CAM/CSME overlays, ABDM layouts."),
]
for i, (name, role, d) in enumerate(team):
    x = 0.40 + (i % 3) * 4.25
    y = 1.50 + (i // 3) * 2.70
    card(s, x, y, 4.05, 2.50, WHITE)
    add_rect(s, x, y, 4.05, 0.10, TEAL if i % 2 == 0 else BLUE)
    add_tb(s, x + 0.22, y + 0.30, 3.60, 0.42, [{"text": name, "size": 20, "bold": True, "color": NAVY}])
    add_tb(s, x + 0.22, y + 0.78, 3.60, 0.36, [{"text": role.upper(), "size": 11, "bold": True, "color": TEAL}])
    add_tb(s, x + 0.22, y + 1.25, 3.60, 0.95, [{"text": d, "size": 13, "color": SLATE_700}])
footer(s, 13)
add_notes(s, "Introduce in 20 seconds. Do not read bios. Point to live demo owners: Bezaleel (flow), Madhu (clinical), Akshay (model).")


# ============================== SLIDE 14: CLOSE ==============================
s = blank()
set_slide_bg(s, NAVY)
add_rect(s, 0, 0, 0.18, H, TEAL)
add_tb(s, 0.70, 0.40, 12, 0.30, [
    {"text": "13  —  WHAT WE WANT JUDGES TO REMEMBER", "size": 12, "bold": True, "color": TEAL}
])
add_tb(s, 0.70, 0.85, 12.2, 1.50, [
    {"text": "We are not building a demo.", "size": 32, "bold": True, "color": WHITE, "space_after": 10},
    {"text": "We are building the honest, open-source system that lets a validated approach actually reach the people who need it.",
     "size": 18, "color": RGBColor(0xCB, 0xD5, 0xE1)}
])

points = [
    ("Quality first", "If the photograph is untrustworthy, there is no grade."),
    ("Offline always", "A PHC with no internet still finishes the screening."),
    ("Humans in the loop", "Operator for the camera. Ophthalmologist for the disease."),
    ("National rails", "FHIR R4 / ABDM — not a walled-garden app."),
]
for i, (t, d) in enumerate(points):
    x = 0.70 + (i % 2) * 6.15
    y = 2.70 + (i // 2) * 1.15
    add_rect(s, x, y, 5.90, 1.00, NAVY_MID, radius=0.06)
    add_tb(s, x + 0.22, y + 0.12, 5.50, 0.32, [{"text": t, "size": 16, "bold": True, "color": TEAL}])
    add_tb(s, x + 0.22, y + 0.48, 5.50, 0.40, [{"text": d, "size": 13, "color": RGBColor(0xE2, 0xE8, 0xF0)}])

add_tb(s, 0.70, 5.20, 12, 0.70, [
    {"text": "Drishti-AI", "size": 22, "bold": True, "color": WHITE, "space_after": 4},
    {"text": "SIH26038  ·  MathWorks  ·  MedTech  ·  Software Prototype",
     "size": 14, "color": TEAL_LIGHT}
])
add_tb(s, 0.70, 6.10, 12, 0.70, [
    {"text": "Bezaleel  ·  Madhu  ·  Akshay  ·  Adithya  ·  Sinduri  ·  Megha",
     "size": 16, "bold": True, "color": WHITE, "space_after": 6},
    {"text": "Live app  ·  docker compose up  ·  localhost:8000/app     ·     Q & A",
     "size": 14, "color": SLATE_400}
])
add_notes(s, "Close on the manifesto. Invite the demo. Do not reopen architecture. If time: ‘ask us to break it with a bad image.’")


# Portable outputs: repo root copy + presentation/ copy, anchored to this file
# so the builder works on any host (previously two absolute macOS paths).
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)
out1 = os.path.join(os.path.dirname(_REPO), "Drishti-AI_SIH2026_Presentation.pptx")
out2 = os.path.join(_HERE, "Drishti-AI_SIH2026_Presentation.pptx")
prs.save(out1)
prs.save(out2)
print("Wrote", out1)
print("Wrote", out2)
print("slides", len(prs.slides))
