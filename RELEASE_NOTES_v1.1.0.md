# Drishti-AI / Netra-AI v1.1.0 — Fully Offline On-Device Screening

First release where **the AI runs entirely on the phone** — no server, no
internet required for screening. Works with airplane mode ON.

## What's inside

- **Bundled model**: `dr_efficientnet_b0_fp32.tflite` (15.3 MB), converted from
  `final_model.keras` and **parity-gated at 100% top-1 agreement** on the
  clinical corpus (`results/tflite_parity_fp32_*.json`). fp16 was measured at
  83.3% agreement and rejected by the gate — we ship correctness over size.
- **On-device pipeline**: quality gate (blur/illumination/contrast/FOV,
  byte-identical thresholds and reason codes with the server pipeline) →
  5-class DR grading → confidence gate (0.60 / 0.15 margin) → routing with
  recapture cap 2 and mandatory human review for referable (grade >= 2) or
  low-confidence results.
- **Encrypted local store** (SQLCipher, Keystore-held key): patients,
  screenings, durable offline queue (survives app kills), consent records,
  local audit trail.
- **Privacy chain**: consent-gated de-identified referral uplink
  (pseudonym = per-device HMAC; image downscaled + EXIF-stripped; fail-closed
  PHI linting on both phone and server). **No patient data is ever stored on
  any cloud server.**

## How to test (5 minutes)

1. Install `app-release.apk` on any Android 8+ phone (sideload — allow
   unknown sources). The universal APK covers arm64/armv7/x86_64.
2. Turn on **airplane mode**.
3. Dashboard → Start New Screening → register a test patient.
4. Capture: pick a bundled fundus sample or any image file.
   - Adversarial images (faces, documents) are rejected on-device with
     `IMG_NOT_FUNDUS` — no DR grade is ever produced for garbage.
5. Result screen shows the grade + **the provenance line
   "on-device • N ms"** — that number is the phone's own measured
   inference time.
6. Kill the app, reopen: history and queued records survive (durable store).
7. (Optional, online) Referral flow asks consent first; with consent, a
   de-identified payload (pseudonym, no name/phone/ABHA/village) is queued
   and uploaded to the doctor console when connectivity returns.

## Honest status (read before judging)

- **Triage-assist, not autonomous diagnosis.** Current model: 71.5% Top-1 on
  external EyePACS validation, referable-DR sensitivity 0.623 at the adopted
  operating point (t*=0.09, specificity 0.775). Every referable or
  low-confidence result routes to mandatory human review. Not CDSCO-cleared;
  not for clinical use.
- **Grad-CAM heatmaps are labelled "model attention — not evidence"**: our
  insertion/deletion truthfulness gate
  (`results/xai_insertion_deletion.json`) currently FAILS on this checkpoint,
  so heatmaps are not presented as causal justification. Gate re-runs after
  the planned retrain.
- **Device matrix pending**: first on-device validation round (latency/RSS on
  2 GB RAM phones) is the next milestone; reported numbers will be added to
  `validation/android_device_matrix.md`.
- **Capture uses file selection / bundled samples in this build** — live
  camera capture (fundus attachment SDKs) is the next integration item.

## Evidence bundle (also attached)

- `tflite_parity_fp32_clinical.json` / `tflite_parity_fp32_scenarios.json` /
  `tflite_parity_fp16_clinical.json` — quantization parity gates
- `xai_insertion_deletion.json` — XAI truthfulness gate (honest FAIL)
- Full test evidence: 40 Flutter tests, 107 Python tests + 119 subtests,
  end-to-end rehearsal (13 steps / 23 assertions) incl. the de-identified
  referral leg.
