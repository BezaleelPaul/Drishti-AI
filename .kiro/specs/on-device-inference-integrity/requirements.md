# Requirements Document

## Introduction

The Drishti-AI screening application is used by field operators in offline or low-connectivity rural settings, and its output is read by clinicians who must be able to trust what the screen tells them. Discovery established that the application's default on-device grading path does not execute a model at all: it derives a grade from an image colour ratio, never fails, and therefore prevents the server path from running, while a correct device-resident model implementation already exists in the codebase but is never invoked. Values the confidence gate relies on are additionally invented rather than measured.

This specification makes one guarantee testable: every preliminary screening grade the application displays originates from a real, successfully executed model, failure is shown as failure, uncertainty is never fabricated, the backend that actually ran is named honestly, and confirmation by the screening service is reported truthfully. It deliberately does not change preprocessing, disagreement policy, explainability, or any clinical threshold.

## Boundary Context (Optional)

- **In scope**: provenance of the on-device grade; fail-closed behaviour when loading, initialization, image preparation, or inference fails; prohibition on synthesized probability, confidence, uncertainty and margin values; preservation of the existing image-quality and non-retinal domain gates ahead of inference; accurate backend identification in the displayed result and in any stored record; distinguishing preliminary from server-confirmed results and requesting confirmation when the configured service is reachable; preservation of existing records and of all staged, unstaged and untracked work; the tests and source checks that prove all of the above; governance of clinical thresholds and claims.
- **Out of scope**: changing preprocessing algorithms, resize or normalisation behaviour, and quality thresholds (owned by the `preprocessing-parity` specification); designing the policy for resolving disagreement between independently produced results (owned by `prediction-consensus`); implementing Grad-CAM or otherwise changing explainability (owned by `explainability-truthfulness`); durable record storage design, queue mechanics, retry and retention behaviour (owned by `offline-record-durability` and `sync-reliability`); model retraining, quantization or architecture change; any change to clinical thresholds or clinical interpretation.
- **Adjacent expectations**: this specification expects the existing image-quality and domain gates to remain in place and the existing screening-analysis service capability to remain available for confirmation requests. It expects stored-record lifecycle and sync behaviour to continue to be owned elsewhere; where this specification requires that a stored record agree with the displayed result, it requires accuracy of the recorded value only, not a change to how records are stored. It expects disagreement resolution to be handled by `prediction-consensus`; this specification only prevents a disagreement from being reported as a confirmation.

## Project Description (Input)

### (a) Who has the problem

Field operators and screeners running the Drishti-AI Flutter app in offline/low-connectivity rural settings; the clinicians who receive its referrals; and anyone reviewing, demonstrating or judging the project. A screening grade displayed without a real model behind it is a patient-safety risk and a credibility risk at the same time.

### (b) Current situation

Verified during repository discovery (all references re-checked against source before finalizing requirements):

- The default on-device grader is not a model. `DrDetectRunner._inferOrdinalRegression` (`flutter_app/lib/services/ml/model_runner.dart:153-163`) computes a red/green luminance ratio clamped to `[0,4]` and returns it as a DR grade.
- `DrDetectRunner.initialize()` loads nothing (`model_runner.dart:60-62`), and the asset it declares, `drdetect_regression_512px.onnx` (`model_runner.dart:45`), does not exist anywhere in the repository.
- Because that path never fails, `flow_analysis_screen.dart:104-111` only calls the server when the local result is null or throws, so the real backend is effectively unreachable and a clinical-looking grade is emitted from a heuristic, labelled `modelBackend='drdetect_ordinal'` (`screening_orchestrator.dart:287`) with no non-diagnostic marker in the UI (`flow_result_screen.dart:48` only maps `'tflite-fp32'`).
- When the ordinal runner returns null the orchestrator synthesizes a 5-class probability vector and derives confidence from it (`screening_orchestrator.dart:224-237`); those invented values then drive the real abstention gate (0.60 confidence / 0.15 margin, `src/pipeline/confidence.py:19,22`, evaluated by `flutter_app/lib/services/ml/confidence_evaluator.dart:37-47`).
- `BuildARunner.predict` ships hardcoded probabilities `[0.70,0.15,0.08,0.04,0.03]` with `referable` always true (`model_runner.dart:202-210`).
- A correct TFLite implementation already exists but is dead code: `DrClassifierDart` genuinely runs inference (`dr_classifier.dart:43` `Interpreter.fromAsset`, `:78` `interpreter.run`, raw 0..255 input at `:69-75`), yet no file in `flutter_app/lib` instantiates it.
- The bundled graph is valid: `flutter_app/assets/models/dr_efficientnet_b0_fp32.tflite` (15.34 MB) has the `TFL3` magic, input `[1,224,224,3]` float32, output `[1,5]` softmax, declared in `flutter_app/pubspec.yaml:95`, with the conversion contract documented at `scripts/convert/convert_to_tflite.py:87-88` (raw 0..255, normalization inside the graph).
- The runtime is viable: `flutter_litert` ^3.8.0 (resolved 3.9.3, `pubspec.lock:248`), Apache-2.0, actively published, supports Android/iOS/Linux/macOS/web/Windows.
- Server-side safety is already correct and must not be disturbed: quality and domain gates run before inference (`src/pipeline/router.py:103` before `:277`), the simulated backend is blocked (`api/services/ai_bridge.py:222-225`), and abstention thresholds are real and tested.
- Current test baseline that must stay green: `pytest -q tests` = 119 passed + 127 subtests; `flutter test` = 57 passed; `flutter analyze` = 0 issues.

### (c) What should change

**Objective:** Ensure that every displayed preliminary screening grade originates from a real, successfully executed model, with honest uncertainty handling and explicit backend status.

### In scope

1. Integrate the existing `DrClassifierDart` TFLite implementation into the live screening path.
2. Remove the luminance-based grading heuristic, hardcoded grades, and fabricated probabilities, confidence, uncertainty, or margin values from the inference and decision paths.
3. Fail closed when model loading or inference fails: no grade may be displayed as a valid model prediction.
4. Preserve existing image-quality and domain gates.
5. Clearly identify the backend that actually executed inference.
6. Distinguish preliminary on-device results from server-confirmed results, and request server confirmation when connectivity and the configured service are available.
7. Test that no synthetic values reach any confidence or abstention gate.
8. Preserve existing records and unrelated working-tree changes.

### Out of scope

- Changing preprocessing algorithms or thresholds.
- Designing the final policy for disagreements between independent model outputs.
- Implementing Grad-CAM or retraining the model.
- Changing clinical thresholds without documented evidence and explicit approval.

### Important constraints

- Do not assume existing softmax outputs are calibrated probabilities.
- Do not reuse the existing referable-score or threshold semantics until their meaning is verified.
- Do not invent clinical performance claims.
- Do not delete files or overwrite unrelated changes.
- Inspect the current Git status and preserve staged, unstaged and untracked work.
- Do not commit, reset, clean or stash the repository without explicit permission.

## Requirements

### Requirement 1: On-device inference provenance

**Objective:** As a field operator, I want every preliminary grade shown on the device to be produced by an actual execution of the bundled model, so that I am never shown a heuristic result presented as an AI screening.

#### Acceptance Criteria

1. When the on-device screening path produces a grade, the Screening Application shall derive that grade exclusively from a completed execution of the bundled device-resident model on the captured image.
2. If the bundled device-resident model did not execute successfully, then the Screening Application shall not attribute any grade to that model.
3. The Screening Application shall not compute a grade from image colour statistics, luminance ratios, fixed constants, or any other non-model heuristic.
4. The Screening Application shall not return fixed, placeholder, or hard-coded grade values from any grader reachable from the live screening path.
5. Where a grader reports that a value is unavailable, the Screening Application shall not substitute a value obtained from any other source to fill that gap.
6. When the on-device path completes, the Screening Application shall associate the produced grade with the identity of the grader that produced it.

### Requirement 2: Fail-closed behaviour when inference fails

**Objective:** As a field operator, I want a failure to be shown as a failure, so that I never mistake an interrupted analysis for a valid screening result.

#### Acceptance Criteria

1. If model loading, initialization, image preparation required for inference, or inference execution fails, then the Screening Application shall not display a screening grade as a valid model prediction.
2. If inference fails, then the Screening Application shall display an explicit unavailable or error state in place of a grade.
3. While an analysis has not completed successfully, the Screening Application shall not display any grade for that image.
4. If the model output fails output validation, then the Screening Application shall withhold the grade and mark the result as requiring human review.
5. When inference fails, the Screening Application shall not report the outcome as an on-device result or as a service-confirmed result.
6. If the model output is withheld, then the Screening Application shall preserve the reason the result could not be produced so that it can be shown to the operator.

### Requirement 3: Honest uncertainty and decision inputs

**Objective:** As a clinician reviewing a flagged result, I want every confidence and abstention input to be a measured value, so that a review flag reflects the model rather than an artefact of the software.

#### Acceptance Criteria

1. The Screening Application shall not synthesize probability vectors, confidence values, uncertainty values, or margins at any point in the screening path.
2. Where the model does not provide a value, the Screening Application shall treat that value as unavailable rather than deriving a substitute for it.
3. When a confidence or abstention decision is evaluated, the Screening Application shall supply only values produced by the model execution itself.
4. If a confidence or abstention gate is presented with an unavailable or invalid value, then the Screening Application shall withhold the grade and require human review.
5. The Screening Application shall treat the model's normalised score distribution as uncalibrated and shall not label or present it to an operator as a calibrated probability.
6. The Screening Application shall not claim that any uncertainty figure is a calibrated or clinically validated quantity.

### Requirement 4: Preserved image-quality and domain gates

**Objective:** As a field operator, I want the existing quality and non-retinal checks to keep blocking unusable images before any inference, so that this change does not weaken an existing safety control.

#### Acceptance Criteria

1. The Screening Application shall execute the existing image-quality assessment and the existing non-retinal domain check before any on-device inference.
2. If the image-quality assessment returns a failing result, then the Screening Application shall not run inference and shall not display a grade.
3. If the non-retinal domain check determines that the image is not a retinal fundus image, then the Screening Application shall not run inference and shall not display a grade.
4. While an image is assessed as borderline quality, the Screening Application shall apply the existing reassessment and retry limits before any grade is displayed.
5. When a gate blocks an image, the Screening Application shall preserve the existing rejection reason and operator-facing message for that block.
6. Where the gates are unchanged by this specification, the Screening Application shall continue to satisfy the existing gate tests without altering their expected outcomes.

### Requirement 5: Accurate backend identification

**Objective:** As a field operator and as a clinician, I want the displayed and stored result to name the backend that actually produced it, so that I am never told a result came from a source that did not run.

#### Acceptance Criteria

1. When a result is displayed, the Screening Application shall display the identity of the backend that actually produced that result.
2. The Screening Application shall not display a backend identity that differs from the backend recorded with that result.
3. Where the same image has been processed by more than one backend, the Screening Application shall report each result against the backend that produced that result.
4. If the backend that produced a result cannot be determined, then the Screening Application shall report the backend as unknown rather than assuming one.
5. Where a result is persisted, the stored record shall carry the same backend identity as the result displayed to the operator.
6. If a displayed backend identity is not recognised by the result view, then the Screening Application shall fall back to an explicit unknown label rather than displaying an arbitrary or misleading identifier.

### Requirement 6: Preliminary versus service-confirmed status

**Objective:** As a clinician, I want to know whether a result has been confirmed by the screening service, so that a preliminary on-device reading is never mistaken for a confirmed one.

#### Acceptance Criteria

1. When an on-device result has not been confirmed by the screening service, the Screening Application shall label the result as preliminary.
2. Where connectivity and a configured screening service are available, the Screening Application shall request confirmation for the same captured image using the existing supported screening-analysis capability.
3. If the screening service returns a result that agrees with the preliminary on-device result, then the Screening Application shall label the result as service-confirmed and record that confirmation against the result.
4. If the screening service is unreachable, times out, or returns an error, then the Screening Application shall leave the result labelled preliminary and shall not upgrade its status.
5. While a result is preliminary, the Screening Application shall require clinician sign-off before the result is presented as final.
6. If the screening service returns a result that differs from the preliminary on-device result, then the Screening Application shall not treat the result as confirmed and shall preserve both results for human review.
7. Where a result is persisted, the stored record shall carry the same confirmation status as the result displayed to the operator.

### Requirement 7: Record and workspace integrity

**Objective:** As the repository owner, I want existing records and all in-progress work preserved, so that this change cannot destroy evidence or another contributor's work.

#### Acceptance Criteria

1. When this change is applied, existing screening records and queued work shall remain present and readable.
2. The Screening Application shall not delete, reset, discard, or overwrite staged, unstaged, or untracked work in the working tree.
3. After the change, the Screening Application shall keep existing stored records retrievable without destructive migration.
4. Changes shall be confined to the on-device screening and result-presentation path; files unrelated to that path shall be left unmodified.
5. The Implementer shall not commit, reset, clean, or stash the repository without explicit human permission.
6. If a required change would remove or overwrite existing work, then the Implementer shall stop and request human approval before proceeding.

### Requirement 8: Verifiable tests and reported evidence

**Objective:** As the reviewer approving implementation, I want machine-checked evidence for every safety claim in this specification, so that I do not have to take any of it on trust.

#### Acceptance Criteria

1. An automated source check shall verify that no non-model heuristic, hard-coded grade, or synthesized probability, confidence, uncertainty, or margin remains reachable from the live screening path.
2. A unit test shall verify that failed model initialization cannot yield a displayed grade.
3. A unit test shall verify that synthesized or unavailable values cannot reach the confidence or abstention gate.
4. An integration test shall verify that the live screening path invokes the bundled-model grader for an image that passes the existing gates.
5. Tests shall verify that the displayed backend label and result status are correct for the preliminary, service-confirmed, service-unavailable, and withheld states.
6. After the change, the Screening Application shall satisfy the existing application test suite, the static analysis check, and the repository Python test suite.
7. The Implementer shall report which checks were run and their real results, and shall not report completion if any check failed.

### Requirement 9: Clinical honesty and threshold governance

**Objective:** As a reviewer, I want no new clinical threshold or performance claim introduced by this change, so that the specification cannot silently alter the clinical meaning of a result.

#### Acceptance Criteria

1. The Screening Application shall not introduce a new decision threshold as part of this change.
2. Where an existing threshold or clinical interpretation is applied, the Screening Application shall apply it unchanged unless separately approved with documented evidence.
3. The Screening Application shall not claim clinical validation, regulatory clearance, or screening-grade performance as part of this change.
4. The Screening Application shall not alter the intended clinical interpretation of any grade.
5. If evidence for a proposed threshold or claim is absent, then the Implementer shall record the item as unresolved rather than proceed.
6. Where the meaning of an existing score or threshold has not been verified, the Screening Application shall not reuse that meaning in a decision gate until it has been verified and explicitly approved.

## Unresolved Decisions

Recorded rather than resolved, per the project constraint not to invent answers. None of these block requirements approval; each must be settled during design with human sign-off.

1. **Canonical backend identifier.** The displayed result currently recognises only `'tflite-fp32'` and `'simulated'` for display, while the live path writes a different set of values (`build_a_legacy`, `drdetect_ordinal`, `build_a`). A single canonical identity for the bundled device-resident model must be chosen, and the recognised display values aligned with it. (Evidence: `flow_result_screen.dart:48`, `results_screen.dart:172`, `screening_orchestrator.dart:287`, `model_runner.dart:50,176`.)
2. **Referable determination on the device path.** Constraint forbids reusing existing referable-score or threshold semantics until verified. Until verified, it must be decided whether the on-device path reports referability at all, or reports only a grade and defers referability to the confirmed result. Evidence of the disputed semantics: `on_device_pipeline.dart:119-125`, `quality_thresholds.dart:94`, `pipeline_schema.dart:47`.
3. **Persistence of on-device results.** The local screening writer currently has no callers, so on-device results are not persisted today. Whether this specification must start persisting them, or only guarantee accuracy where persistence already occurs, is a scope question for design against `offline-record-durability`. (Evidence: `local_store.dart:191-248`, no call sites in `flutter_app/lib`.)
4. **Confirmation retry behaviour.** Whether an unconfirmed preliminary result should be re-requested automatically later, or only on operator action, is owned by `sync-reliability`; this specification fixes only that a failed confirmation must not upgrade status.
5. **Uncertainty threshold for withholding.** The on-device gate applies an additional uncertainty threshold with no counterpart on the server. Whether to keep, align, or remove it must not be decided inside this specification, because thresholds are governed by Requirement 9.
