# Evaluation Results — External Validation on Labeled Fundus Data

Honest measurement of the shipped Drishti-AI components on real, third-party
labeled data. Everything below is reproducible from this repository; no numbers
are copied from model cards without re-measurement.

**Headline:** the pipeline is *safe* (it refuses non-retinal input, defers
uncertainty, and never silently releases a referral), but the shipped
EfficientNetB0 classifier has **low referable-DR sensitivity (21%)** on external
data. The system is therefore positioned as a **triage-assist with mandatory
human review**, never as an autonomous screener.

---

## 1. Setup

| Item | Value |
|---|---|
| Dataset | `youssefedweqd/Diabetic_Retinopathy_Detection` (HuggingFace, MIT license) |
| Split | `data/validation-00000-of-00001.parquet` — **2,810 images**, real EyePACS-style screening photographs |
| Labels | 5-class DR severity {0..4}; distribution `{0: 2065, 1: 195, 2: 423, 3: 70, 4: 57}` |
| Referable DR definition | grade ≥ 2 (moderate NPDR and above) — 550 positives / 2,260 negatives |
| Classifier | `final_model.keras` (EfficientNetB0, APTOS-2019-trained), via `DRClassifier` (keras backend) |
| Model card's own claim | **72% accuracy, macro-F1 0.57** on 550 held-out APTOS images (author's number, not ours) |
| Preprocessing | 224×224 float32 input; Rescaling/Normalization are **inside** the saved model (verified via `model.summary()`), matching the card's usage snippet |
| Label sanity | Stratified visual spot-check of all 5 grades (pathology consistent with grade) |
| Tooling | `evaluate_labeled_dataset.py` → `results/labeled_evaluation.json`, per-image audit trail in `results/labeled_evaluation_predictions.csv` |

Reproduce:

```
python evaluate_labeled_dataset.py                 # full 2810, ~21 min
python evaluate_labeled_dataset.py --limit 400 --mode quality
python evaluate_labeled_dataset.py --from-csv results/labeled_evaluation_predictions.csv   # instant re-analysis
```

---

## 2. Model 2 (DR grading) — external accuracy

All 2,810 images, gate bypassed (`model_all_images`):

| Metric | Ours (EyePACS external) | Model card (APTOS holdout) |
|---|---|---|
| Top-1 accuracy | **71.5%** | 72% |
| ±1 agreement | 82.4% | — |
| Macro-F1 | **0.26** | 0.57 |
| Weighted-F1 | 0.65 | 0.73 |
| Balanced accuracy | 0.25 | — |
| QWK | **0.31** | not reported |
| ECE (10-bin) | 0.064 | not reported |

Per-class performance (external set):

| Grade | Support | Precision | Recall | F1 |
|---|---|---|---|---|
| 0 No DR | 2065 | 0.770 | **0.942** | 0.847 |
| 1 Mild | 195 | 0.041 | **0.021** | 0.027 |
| 2 Moderate | 423 | 0.291 | **0.114** | 0.163 |
| 3 Severe | 70 | 0.000 | **0.000** | 0.000 |
| 4 Proliferative | 57 | 0.550 | **0.193** | 0.286 |

Confusion matrix (rows = true, cols = predicted):

```
        0     1     2     3     4
  0  1945    60    57     0     3
  1   182     4     9     0     0
  2   343    26    48     1     5
  3    38     4    27     0     1
  4    18     4    24     0    11
```

Referable-DR triage (grade ≥ 2):

| | Value |
|---|---|
| Sensitivity | **0.213** (117/550) |
| Specificity | 0.970 |
| PPV | 0.629 |
| NPV | 0.835 |

**Interpretation (no spin):**
- The headline accuracy **matches the model card's own number** (71.5% vs 72%) —
  nothing was lost in integration or preprocessing.
- But that accuracy is carried almost entirely by the majority class. Minority
  recall collapses under external domain shift: severe NPDR recall is **0/70**,
  and referable-DR sensitivity is **21%**, far below anything acceptable for
  autonomous screening (published screening systems target ≥ 90%).
- Accuracy on a 73%-negative dataset is a vanity metric; macro-F1/QWK/sensitivity
  are the honest ones, and they are weak.

---

## 3. Domain gate (Model 0) — non-retinal input is refused

| Metric | Full set (n=2810) | Stratified 400 |
|---|---|---|
| FUNDUS (accepted) | 2552 (93.1%) | 365 (91.3%) |
| UNDETERMINED (deferred to quality gate) | 63 (2.2%) | 9 (2.3%) |
| NOT_FUNDUS (rejected) | **195 (6.9%)** | 26 (6.5%) |
| Reject reasons | band 156 / red-blue 39 | — |

Reject reasons are retinal-colour failures on images the gate judged
non-retinal; spot-checked rejects were heavily washed-out/colour-cast frames.
This false-reject rate is the *known cost* of the gate (42% → 6.9% after
calibration on 400 images) and it is the price of the property below.

Safety property (the point of the gate): **all 14 adversarial non-retinal
fixtures in `test_samples/03_adversarial_non_fundus/` are rejected**, including
faces, documents, screenshots, landscapes, and the historical API face uploads
that previously produced a fabricated Grade 0. Enforced by
`tests/red_team/test_corpus_sweep.py` (76 subtests) in CI.

---

## 4. Model 1 (quality gate) — full 2,810-image run, retuned

Domain gate: coverage 93.1% (FUNDUS 2552 / NOT_FUNDUS 195 / UNDETERMINED 63).
Among the 2,615 images that reached Model 1:

| Grade | Count | Share (of 2,810) |
|---|---|---|
| GOOD | 392 | 13.9% |
| BORDERLINE (→ reassessment) | 1,587 | 56.5% |
| BAD (→ recapture guidance, incl. 195 domain rejects) | 831 | 29.6% |
| **Pass fraction (GOOD+BORDERLINE)** | | **75.7%** (was 40.9%; 73.5% on the earlier stratified-400 cross-check) |

**How it was retuned (same discipline as the domain gate):** we dumped every
quality metric for 600 stratified screening images *and* joined them with the
DR model's prediction on the same images. Finding: the 15–35 Laplacian band
(rejected as "severe blur") scored the same DR accuracy as the 35–85 band
that was already admitted as borderline (0.398 vs 0.401 balanced-sample) —
the threshold was cutting usable images without catching anything worse.
`blur_bad_threshold` went 35 → 15 (`checker.py`), which:

- raises the pass rate from 40.9% → **75.7%** on the full real screening set,
- keeps **every** corpus failure fixture BAD (motion blur 1.2, glare,
  underexposure, `scenario_2_bad`, `scenario_3` are all ≤ 3 on sharpness),
- flips exactly one corpus image: `real_clinical_fundus_patient1`
  (a genuine clinical fundus) from BAD → BORDERLINE,
- leaves all safety tests green (29 unit / 29 red-team / 11 integration,
  pytest 86 + 117 subtests).

Remaining BADs are dominated by the ML-ensemble cutoff and gross blur, not by
the metric we relaxed. Model 1 still never creates a wrong prediction — it
can only over-refuse, which is the safe direction.

---

## 5. Uncertainty gate (Section 7) — what is actually released

Thresholds: confidence ≥ 0.60, top-2 margin ≥ 0.15 (`ConfidenceConfig`).

| Subset | n | Accuracy | Referable sensitivity |
|---|---|---|---|
| All (gate bypassed) | 2810 | 0.715 | 0.213 |
| After domain gate | 2615 | 0.719 | 0.201 |
| **Released** (confident + unambiguous) | 2138 (76.1%) | 0.782 | **0.043** |
| Abstained (→ human review) | 672 (23.9%) | — | — |

**Interpretation:** the gate does exactly what it was designed to do — it
abstains on a quarter of cases and its released subset is more accurate than
the whole. It must **not** be read as "the system is 78% accurate": released
sensitivity for referable DR is 4%, because the model's *confident* predictions
are overwhelmingly "No DR". Under-referral is the clinical risk here, and the
mitigations are architectural and already in the code:

- every referable prediction forces clinician review regardless of confidence
  (`router.py`, `referable_review`),
- uncertain predictions are retained as provisional for over-read, never
  silently finalized (`error_code=AI_LOW_CONFIDENCE`),
- the Flutter app withholds a grade and shows recapture guidance instead of
  inventing one.

---

## 6. Operating-point sweep — a sensitivity lever exists, and its limits

Shipped policy is argmax: predict referable iff the top-1 class ≥ 2. That sits
far to the right of the trade-off curve (very specific, very insensitive).
`operating_point_sweep.py` re-cuts the same 2,810 images at every threshold on
the referable probability mass (`p2 + p3 + p4`), using the probabilities stored
in `results/labeled_evaluation_predictions.csv`:

| Operating point | Threshold | Sensitivity | Specificity | PPV | Balanced acc |
|---|---|---|---|---|---|
| **Shipped (argmax)** | — | 0.213 | 0.970 | 0.629 | 0.591 |
| Youden-J optimum | 0.10 | 0.569 | 0.791 | 0.399 | 0.680 |
| High-specificity option | 0.25 | 0.364 | 0.921 | 0.528 | 0.642 |
| Spec ≥ 0.85 kept | 0.15 | 0.473 | 0.854 | 0.441 | 0.663 |
| Sensitivity ≥ 0.90 | any | — | **unreachable** — would require flagging everything (spec → 0) |

**Held-out check** (`--holdout`, stratified 50/50 split, t\* tuned on the
calibration half only, reported once on the 1,407-image test half):

| Operating point (test half) | Threshold | Sensitivity | Specificity | Balanced acc |
|---|---|---|---|---|
| Shipped argmax | — | 0.250 | 0.971 | 0.610 |
| **t\* = 0.09 (calibration-tuned)** | 0.09 | **0.623** | 0.775 | **0.699** |

**Reading:**
- Threshold choice alone **more than doubles** referable sensitivity
  (0.21 → 0.57 same-set; 0.25 → 0.62 held-out) while staying useful,
  improving balanced accuracy 0.59 → 0.68 (0.61 → 0.70 held-out). This is a
  real, zero-training lever, and the held-out half confirms it transfers
  beyond the tuning sample.
- But sensitivity ≥ 0.90 **cannot be bought with thresholds** — the model's
  probability mass on referable classes is too low. Model improvement (binary
  referable head / fine-tuning, the P1 already in ROADMAP) is the only path to
  screening-grade sensitivity.
- Same-set table rows are optimistic by construction (the held-out rows are
  the ones to quote). Full tables: `results/operating_point_sweep.csv`,
  `results/operating_point_sweep.json`.

---

## 7. Limitations

1. **Third-party labels.** Labels come with the public dataset; they were not
   re-adjudicated by us. A visual spot-check found them plausible.
2. **Single external dataset, single camera distribution.** No multi-site or
   prospective validation.
3. **Class imbalance** (73% grade 0) inflates accuracy; prefer macro-F1/QWK/
   sensitivity when comparing.
4. **One held-out split, not prospective.** The section 6 operating point is
   tuned on a calibration half and confirmed on a held-out test half of the
   *same* dataset; deployment would want external prospective calibration.
5. **Not a clinical claim.** This is a hackathon research benchmark; the model
   card itself states "Not for clinical use".

## 8. What these numbers say the product should do

- Sell the **safety architecture** (domain gate → quality gate → uncertainty
  gate → mandatory human review → audit trail), which is measured and enforced
  by tests — not a headline accuracy that the model does not have.
- Next model work (P1): fine-tune on the combined APTOS+EyePACS data or add a
  referable-vs-not binary head, targeting referable sensitivity ≥ 0.9 before
  anyone claims screening-grade performance.
- Calibration work (P1), **all three done**: Model 1 thresholds recalibrated
  on a 600-image metric+prediction join (pass fraction 40.9% → **75.7%**
  full-set, every corpus failure fixture still rejected, section 4); the
  referable operating point calibrated and confirmed on a held-out split
  (sens 0.25 → 0.62, section 6); full-set Model 1 run completed.
- The one remaining P1: model improvement for referable sensitivity —
  thresholds alone top out near 0.62 and cannot reach screening-grade 0.9.
