# Brief: preprocessing-parity

## Problem
The Dart on-device path and the Python server path do not compute the same tensor from the same image, and there is no test that would catch it. Since the same patient image can be graded on-device and on the server, a systematic preprocessing divergence produces systematically different grades for identical input — and today, nothing detects that. Compounding it, the existing "parity" test suite only covers the quality gate and the confidence evaluator (`flutter_app/test/adversarial_gate_parity_test.dart:7-8`, `quality_gate_test.dart:9`, `confidence_evaluator_test.dart:6`); **no DR preprocessing parity test exists in either language**.

## Current State
Verified by direct comparison of the two implementations:

| Step | Python | Dart | Match |
|---|---|---|---|
| Max decode dim | 4096 (`src/image_io.py:27`) | 4096 (`quality_gate.dart:662`) | MATCH |
| Gray weights | 0.299/0.587/0.114 (`image_io.py:105`) | same (`quality_gate.dart:356`) | MATCH |
| Channel order | RGB (`classifier.py:189-190`) | RGB (`quality_gate.dart:707-709`) | MATCH |
| Border crop (`gray > 7` bbox) | present (`classifier.py:191-197`) | **absent** | **MISMATCH** |
| Circle mask | `cv2.circle` radius `min//2` (`classifier.py:199-204`) | center-square only (`model_runner.dart:114-123`) | **MISMATCH** |
| Ben Graham enhancement | **before** resize, `GaussianBlur((0,0),20)` (`classifier.py:206-207`) | **after** resize, `radius:10` (`model_runner.dart:126-134`) | **MISMATCH** |
| Resize | `cv2.INTER_AREA` (`classifier.py:208`) | `Interpolation.cubic` (`model_runner.dart:130`) | **MISMATCH** |
| `/255` scaling | present (`classifier.py:211`) | **absent** | **MISMATCH** |
| ImageNet mean/std | `[0.485,0.456,0.406]` / `[0.229,0.224,0.225]` (`classifier.py:212-213`) | **absent** (0 grep hits in `flutter_app/`) | **MISMATCH** |
| Layout | NCHW (`classifier.py:217`) | no tensor produced | **MISMATCH** |
| Ordinal cut-points | `[0.5,1.5,2.5,3.5]` (`classifier.py:57`) | same (`model_runner.dart:46`) | MATCH |
| Quality thresholds | (`checker.py:62-84`) | (`quality_thresholds.dart:10-42`) | MATCH |

Important nuance: the missing `/255` and ImageNet normalization may be **correct** for the shipped TFLite graph, whose normalization lives inside the graph (`scripts/convert/convert_to_tflite.py:87-88`, "raw float32 in [0,255] … normalization lives inside the graph"), while `classifier.py:211-213` applies them for the ONNX/Keras path. The mismatch that matters is therefore per-backend, and must be established by measurement rather than by inspection. Unverified today: whether `package:image` `Interpolation.cubic` numerically matches PIL bicubic; `validate_tflite_quantized.py` gates Python-side parity only.

## Desired Outcome
For a given input image, the tensor fed to the on-device model and the tensor fed to the server model are identical up to a documented, measured tolerance — or the divergence is explicitly documented as backend-specific and intentional. A CI-enforced golden parity test fails if either side drifts.

## Approach
First produce a measured parity report: run a fixed corpus of committed images (`test_samples/`) through both the Python preprocessing function and the Dart preprocessing function, and diff the resulting tensors numerically (max abs error, mean abs error, per-stage). Classify each of the table rows above as *required for parity*, *backend-specific by design*, or *defect*. Then fix the defects, express the intentional per-backend differences as a single documented contract in one place, and land a golden test: the Python side writes reference tensors/metrics for the corpus, the Dart test reads them and asserts within tolerance. Wire it into CI via `test-ci-coverage-gate`.

## Scope
- **In**: a measured cross-language parity report over the committed corpus; classification of every preprocessing step as required, intentional or defect; fixes for the true defects; a single documented preprocessing contract; golden parity tests in both languages wired into CI; a numeric drift check for Dart-vs-PIL bicubic resize.
- **Out**: changing the model or its input size; quality-gate thresholds (already at byte parity and tested); retraining; introducing new image augmentations; the Grad-CAM path.

## Boundary Candidates
- Measurement harness (produce comparable tensors from both stacks)
- Contract definition (one authoritative statement of per-backend preprocessing)
- Defect fixes (align the Dart implementation where parity is required)
- Golden test assets and CI wiring

## Out of Boundary
- On-device runner wiring and output-contract integrity (`on-device-inference-integrity`).
- What to do when device and server grades disagree (`prediction-consensus`).
- Modifying `classifier.py` behavior in ways that change server accuracy — any server-side change requires re-running `evaluate_labeled_dataset.py` and updating `claims-evidence-fidelity`.

## Upstream / Downstream
- **Upstream**: `src/classification/classifier.py`, `flutter_app/lib/services/ml/{model_runner,dr_classifier,quality_gate}.dart`, `scripts/convert/convert_to_tflite.py`, `test_samples/` corpus.
- **Downstream**: `on-device-inference-integrity` (correct inputs for the real grader), `explainability-truthfulness` (Grad-CAM must use the graded tensor), `prediction-consensus` (meaningful comparison requires parity first).

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `on-device-inference-integrity` must land first (there must be a real grader to compare); `test-ci-coverage-gate` hosts the CI wiring.

## Constraints
- Existing green suites must stay green; parity tests are additive.
- Tolerances must be measured, not chosen arbitrarily, and recorded with the report.
- If correcting a mismatch would change server-side accuracy, that is out of scope — document and escalate instead.
- No new dependencies beyond what the two stacks already use for image handling.
