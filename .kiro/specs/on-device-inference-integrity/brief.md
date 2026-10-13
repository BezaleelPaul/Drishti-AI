# Brief: on-device-inference-integrity

## Problem
The app's default on-device grader is not a model. `DrDetectRunner._inferOrdinalRegression` (`flutter_app/lib/services/ml/model_runner.dart:153-163`) computes a red/green luminance ratio clamped to `[0,4]` and calls it a DR grade; `initialize()` loads nothing (`model_runner.dart:60-62`); the asset it declares, `drdetect_regression_512px.onnx` (`model_runner.dart:45`), does not exist in the repo. Because this path never fails, `flow_analysis_screen.dart:104-111` only calls the server when the local result is null or throws — so the real backend is effectively unreachable and a clinical-looking grade is emitted from a heuristic, labelled `modelBackend='drdetect_ordinal'` (`screening_orchestrator.dart:287`), with no non-diagnostic marker in the UI (`flow_result_screen.dart:48` only maps `'tflite-fp32'`).

Compounding it, when the ordinal runner returns null the orchestrator **invents** a 5-class probability vector and derives confidence from it (`screening_orchestrator.dart:224-237`), which then satisfies or fails the real 0.60/0.15 abstention gate (`src/pipeline/confidence.py:19,22`, `confidence_evaluator.dart:37-47`) — the safety gate is being fed fabricated numbers. `BuildARunner.predict` also ships hardcoded probabilities `[0.70,0.15,0.08,0.04,0.03]` with `referable` always true (`model_runner.dart:202-210`).

## Current State
- **Working code that is never called**: `DrClassifierDart` genuinely runs TFLite — `Interpreter.fromAsset` (`dr_classifier.dart:43`), `interpreter.run` (`dr_classifier.dart:78`), correct raw 0..255 float input (`dr_classifier.dart:69-75`). Grep finds **zero instantiations** of `DrClassifierDart` anywhere in `flutter_app/lib`.
- **Bypass confirmed**: `flow_capture_screen.dart:30` and `flow_analysis_screen.dart:37` construct `OnDevicePipeline()` with no arguments, which defaults to `DrDetectRunner()` (`on_device_pipeline.dart:17`, `screening_orchestrator.dart:63`).
- **The model is real**: `flutter_app/assets/models/dr_efficientnet_b0_fp32.tflite` (15.34 MB) has the `TFL3` magic, input `[1,224,224,3]` float32, output `[1,5]` softmax; contract documented at `scripts/convert/convert_to_tflite.py:87-88` and `flutter_app/assets/models/README.md` (fp32, "100% top-1 parity", declared at `pubspec.yaml:95`).
- **Runtime is fine**: `flutter_litert` 3.9.3, Apache-2.0, actively published, supports Android/iOS/Linux/macOS/web/Windows; classic `Interpreter` API documented as supported.
- **Server side is already correct** and must not be disturbed: simulated backend blocked (`api/services/ai_bridge.py:222-225`), quality gate before inference (`src/pipeline/router.py:103` vs `:277`), abstention thresholds real and tested.

## Desired Outcome
The on-device result shown to an operator comes from the bundled TFLite model or the system refuses to show a grade. No probability, confidence or margin anywhere in the pipeline is synthesized. The UI states which backend produced a result and marks on-device output as preliminary pending server confirmation. Server disagreement or unavailability is visible rather than silently bypassed.

## Approach
Wire `DrClassifierDart` through `DrDetectRunner` as the real ordinal/softmax grader (or replace `DrDetectRunner`'s internals with it), keeping the existing `DrModelRunner`/`DrModelOutput` interchangeable-grader interface intact. Delete `_inferOrdinalRegression`'s luminance heuristic, the `BuildARunner` hardcodes, and the fabricated probability/confidence/top2-margin synthesis — replace with a fail-closed "no probability available" state that propagates to the abstention gate rather than being invented. Add explicit backend labeling plus a "preliminary — pending server confirmation" state in the result screens, and make the server call unconditional when connectivity exists (moving the current null/throw-only fallback into `prediction-consensus`).

## Scope
- **In**: `DrClassifierDart` wired into the live screening path; removal of the luminance heuristic, hardcoded outputs and synthesized probabilities/confidence/margins; fail-closed handling when probabilities are genuinely unavailable; honest backend labeling and a preliminary-result state in the UI; unit tests proving no fabricated values reach the confidence gate; server confirmation requested whenever connectivity exists.
- **Out**: preprocessing numeric parity (owned by `preprocessing-parity`); device-vs-server disagreement policy (owned by `prediction-consensus`); Grad-CAM (owned by `explainability-truthfulness`); any change to the server-side confidence thresholds or router; model retraining or int8 quantization.

## Boundary Candidates
- Grader wiring (which runner actually executes, and with what artifact)
- Output contract integrity (what fields are real vs synthesized)
- Fail-closed states (model missing, interpreter error, probabilities null)
- Backend labeling and preliminary-result presentation in the UI

## Out of Boundary
- Deciding what to do when device and server disagree (deferred to `prediction-consensus`).
- Matching Dart preprocessing numbers to Python (deferred to `preprocessing-parity`).
- Any change to `src/pipeline/router.py` abstention semantics.

## Upstream / Downstream
- **Upstream**: `flutter_app/assets/models/dr_efficientnet_b0_fp32.tflite`, `scripts/convert/convert_to_tflite.py`, `flutter_litert`, `src/pipeline/confidence.py` (shared thresholds).
- **Downstream**: `preprocessing-parity` (needs a real grader to compare), `explainability-truthfulness` (needs the graded model identified), `prediction-consensus` (needs two real predictions), `screening-ux-consolidation`.

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `preprocessing-parity` and `prediction-consensus` both edit `screening_orchestrator.dart` — land this spec first and rebase those on it.

## Constraints
- `pytest tests` (119 + 127 subtests), `flutter test` (57) and `flutter analyze` (0 issues) must remain green.
- The `DrModelRunner`/`DrModelOutput` interchangeable-grader abstraction must be preserved, not replaced.
- No new packages; `flutter_litert` is already a dependency.
- If the model or interpreter cannot be loaded, the app must withhold the grade rather than fall back to a heuristic.
- On-device output must never be presented to an operator as a confirmed result.
