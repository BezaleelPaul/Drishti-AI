# Roadmap

## Overview

Drishti-AI is an existing, largely complete offline-first diabetic retinopathy screening prototype (FastAPI backend + Flutter app + Keras/ONNX/TFLite model stack) with a genuinely honest evidence base. Verified live during discovery: `pytest tests` = 119 passed + 127 subtests, `flutter test` = 57 passed, `flutter analyze` = 0 issues, the quality and domain gates really do fail closed before inference (`src/pipeline/router.py:103` before `:277`), and the headline accuracy numbers in README (71.5% acc, QWK 0.31, referable sensitivity 0.21, ECE 0.064) match `results/labeled_evaluation.json` exactly.

This phase adds no features. It closes the gap between what the system appears to do and what it actually does, in five areas: (1) the default on-device grader is a red/green luminance heuristic that never fails and blocks the real server path, so a clinical grade is emitted from a non-model with fabricated confidence; (2) Dart and Python DR preprocessing do not match and no DR preprocessing parity test exists; (3) Grad-CAM on the default ONNX backend falls back to a synthetic non-model saliency whose truthfulness gate failed 0/4, while three UI screens render decorative gradients labelled "Grad-CAM"; (4) the local record state machine is dead code, there is no conflict resolution, retention is default-off, and five silent data-loss paths exist; (5) CI never executes the PHI/de-identification contract tests, no coverage is measured anywhere, and three headline performance claims trace to a third-party model card rather than a committed artifact. Everything ships as small, independently testable specs behind the existing green suites so nothing that works today breaks.

## Approach Decision

- **Chosen**: Fail-closed correctness-first — wire the already-written but unused real TFLite classifier into the live path, make every quality/uncertainty/device-vs-server conflict stop or escalate to human review, and make every published number traceable to a committed artifact.
- **Why**: The viability check found the correct on-device classifier already exists as dead code (`flutter_app/lib/services/ml/dr_classifier.dart:43,78`, zero instantiations anywhere), the bundled graph is a valid TFLite model with a documented contract (input `[1,224,224,3]` float32 raw 0..255, output `[1,5]` softmax, normalization inside the graph — `scripts/convert/convert_to_tflite.py:87-88`), and `flutter_litert` 3.9.3 is actively maintained, Apache-2.0, and supports Android/iOS/Linux/macOS/web/Windows. This is a wiring + parity + guardrail job, not a rebuild, so it carries the lowest risk to working functionality.
- **Rejected alternatives**:
  - *Gate-only on device (any grade requires the server)* — rejected: destroys the offline-first value proposition when a real local model is already bundled and parity-gated.
  - *Keep the stub, label it honestly* — rejected: a non-model emitting a DR grade is unsafe regardless of labeling, and its never-failing behavior is precisely what makes the server path unreachable (`flow_analysis_screen.dart:104-111`).
  - *Replace the on-device model/runtime or retrain* — rejected: adds retraining and re-evaluation evidence burden, and the bundled fp32 graph already reports 100% top-1 parity (`flutter_app/assets/models/README.md`).

## Scope

- **In**: on-device inference integrity and honest backend labeling; Dart-vs-Python DR preprocessing parity plus a golden cross-language parity test suite; Grad-CAM provenance and removal of decorative overlays; device-vs-server consensus with abstention on disagreement; CI running the real suite plus a measured coverage gate; durable offline record lifecycle with retries, dead-letter escalation and enforced retention; removal or correction of unevidenced claims; consolidation to a single canonical flow with an accessibility and error-handling baseline.
- **Out**: any model training, retraining or architecture change; clinical validation studies and regulatory submissions; Postgres/Redis migration; a patient-identity/ownership model; FastAPI contract redesign; new visual design language; any new product feature.

## Constraints

- Existing suites must stay green after every spec: `pytest tests` (119 + 127 subtests), `flutter test` (57), `flutter analyze` (0 issues).
- No new heavy dependencies. Prefer removing unused packages (`requests`, `flame`) over adding any.
- Never emit a grade the system cannot defend. Image-quality failures, low confidence, and unresolved device/server disagreement stop or escalate to a qualified human reviewer.
- No clinical-validation, regulatory or accuracy claim without a committed artifact in the repository.
- No broad refactoring, no model replacement, and no deletion of working architecture without justification; specs are merged one at a time behind review.

## Boundary Strategy

- **Why this split**: each spec owns exactly one failure class and one verification artifact, so each can be implemented, tested and merged independently — integrity (does a real model run?), parity (do both stacks compute the same tensor?), explainability (is the map from the model that graded?), consensus (do device and server agree?), durability (does a record survive a process kill?), sync (does permanent failure escalate instead of vanishing?), CI (are safety tests actually executed?), claims (is every number traceable?), consolidation (is there one flow left to test?).
- **Shared seams to watch**:
  - `flutter_app/lib/services/ml/screening_orchestrator.dart` is written by inference-integrity, preprocessing-parity, prediction-consensus and screening-ux-consolidation. Land `on-device-inference-integrity` first; the others rebase on it.
  - Abstention thresholds (`0.60` confidence / `0.15` margin, `src/pipeline/confidence.py:19,22`; on-device `uncertainty > 0.4`, `screening_orchestrator.dart:256`) are shared policy. Parity and consensus must converge them, not fork them.
  - `preprocessing-parity` defines the reference contract consumed by both `on-device-inference-integrity` and `explainability-truthfulness`.
  - Claim edits touch `ROADMAP.md` and `presentation/`, which `demo_rehearsal.py` depends on — keep the rehearsal green.
  - Server-side abstention and quality gates are already correct and tested; specs extend the guardrails, they do not rewrite `src/pipeline/router.py`.

## Specs (dependency order)

- [ ] claims-evidence-fidelity -- Remove or evidence every unevidenced performance/clinical claim and correct contradicted doc numbers. Dependencies: none
- [ ] test-ci-coverage-gate -- Make CI run the full pytest suite (including the PHI/de-id contract) and add measured coverage with a gate. Dependencies: none
- [ ] on-device-inference-integrity -- Wire the real TFLite classifier into the live path, delete fabricated outputs, label the backend honestly, require server confirmation. Dependencies: none
- [ ] offline-record-durability -- Await boot persistence, eliminate the five silent data-loss paths, surface persistence state, resolve the dead LocalStore state machine. Dependencies: none
- [ ] preprocessing-parity -- Make Dart DR preprocessing numerically match Python and add a golden cross-language parity test suite. Dependencies: on-device-inference-integrity
- [ ] explainability-truthfulness -- Generate Grad-CAM from the model that produced the grade or withhold it; remove decorative overlays from the UI. Dependencies: on-device-inference-integrity
- [ ] sync-reliability -- Auto-retry with backoff, dead-letter escalation, doctor-verdict back-sync, scheduled retention enforcement, documented conflict policy. Dependencies: offline-record-durability
- [ ] prediction-consensus -- Cross-check on-device vs server predictions and abstain/escalate on disagreement. Dependencies: preprocessing-parity
- [ ] screening-ux-consolidation -- Single canonical Figma 7-step flow, unified patient/result models, global error handling, accessibility baseline. Dependencies: on-device-inference-integrity

## Existing Spec Updates

None — this is the first spec set in the repository (`.kiro/specs/` was empty at discovery time).

## Direct Implementation Candidates

Small, self-contained items that should not be forced into a spec. Recommend doing these before or alongside the first spec.

- [ ] path-traversal-guard -- Regex-restrict `pseudo_screening_id` (`api/schemas.py:332`) since it is interpolated into a filesystem path (`api/routes/sync_v2.py:131-133`). One-line fix; do immediately.
- [ ] ios-camera-permissions -- Add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to `flutter_app/ios/Runner/Info.plist` (absent today, so live capture would be denied on iOS).
- [ ] dependency-hygiene -- Drop unused `requests` (`requirements-runtime.txt:23`), evaluate dropping `flame` (scanner animation only, `widgets/scanner/scanner_view.dart:5`), and decide whether `google_fonts` fetches fonts at runtime (contradicts the "zero runtime API calls" claim).
- [ ] pytest-collection-fix -- Exclude vendored `external/` from pytest collection so root `pytest` and `make test` work (currently 13 `ModuleNotFoundError: matplotlib` during collection).
- [ ] sample-attribution -- Extend `test_samples/ATTRIBUTION.md` to cover `real_clinical_*` (DRIMDB/Berens license) and `phone_random/*` (no attribution at all).
- [ ] keystore-rotation -- Rotate the plaintext keystore password in `flutter_app/android/key.properties` if that folder was ever shared (gitignored, never committed).
- [ ] demo-phi-prefill -- Remove prefilled demo patient data at `patient_checkin_screen.dart:26-30`, which contradicts the stated policy at `checkin_screen.dart:16-17`.
