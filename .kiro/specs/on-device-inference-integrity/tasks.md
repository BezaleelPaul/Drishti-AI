# Implementation Plan

- [ ] 1. Foundation: status vocabulary and honest measurement building blocks
- [x] 1.1 Result-status vocabulary, confirmation value, and provenance fields on the result model
  - Introduce the six-value status vocabulary (preliminary, service-confirmed, service-disagreed, service-produced, unavailable, withheld) and the confirmation value carrying agreement, server backend, server grade and server screening id.
  - Add optional status and confirmation fields to the screening analysis model with copy-on-change construction so an existing result is never mutated; reading a payload without those keys leaves them null.
  - Provide the pure derivation rule (precedence: quality/decode rejection → none; agreed confirmation → confirmed; disagreement → disagreed; clean server result → produced; no grade → unavailable; flagged grade → withheld; else preliminary) and the pure merge rule (server error, offline fallback or missing server grade → no confirmation; otherwise agreement by equal DR grade).
  - Observable completion: each of the six states derives to its expected value, a merge produces a new instance while the original stays unchanged, and the app compiles with the model layer alone.
  - _Boundary: result_status module, ScreeningAnalysisModel_
  - _Requirements: 5.3, 6.1, 6.3, 6.4, 6.6, 8.5_

- [ ] 1.2 (P) Measurement-only score derivation and truthful record backend
  - A single shared derivation computes normalised scores, top-1 confidence and top-1 minus top-2 margin from a model-provided score vector, used by the classifier's own result building and consumed by the orchestrator conversion wired in 2.2 so the two can never disagree.
  - The classifier delegates its result construction to that derivation (identical numbers to today — existing evaluator tests must stay green).
  - The stored screening record's backend field becomes nullable with no default claim, so a record written when no model ran can no longer assert one did.
  - Observable completion: classifier output values are unchanged (existing confidence-evaluator tests pass untouched), and a quality-gate-only record now carries no backend instead of claiming the device model.
  - _Boundary: score-derivation factory, ScreeningRecordDart, DrClassifierDart_
  - _Requirements: 1.5, 2.5, 3.3, 5.4_

- [ ] 1.3 Stored records carry the true backend and status
  - The local screening writer takes backend and status as required Dart inputs with no default that could assert a model ran — the SQLite `model_backend` column default `'tflite-fp32'` is retained unchanged and documented as residual debt — and stores status in a new nullable column created by a guarded additive migration.
  - Existing rows are never rewritten and remain readable; the schema version increments exactly once.
  - Observable completion: insert-then-read returns exactly the supplied backend and status; a legacy row without status still reads back and is retrievable.
  - _Depends: 1.1_
  - _Boundary: LocalStore_
  - _Requirements: 5.5, 6.7, 7.1, 7.3_

- [ ] 2. Core: the real model on the live path, with failures shown as failures
- [ ] 2.1 Make the bundled TFLite classifier the only default grader, with the canonical identity
  - Both default-grader construction sites construct the adapter over the real classifier instead of the luminance runner, and the adapter reports the canonical on-device identity the display layer already recognises.
  - Referable reporting stays exactly as today (grade ≥ 2 plus the documented mass rule); no threshold expression is edited anywhere.
  - Observable completion: constructing the pipeline or orchestrator with no arguments yields a runner identified by the canonical device id, and no production construction site references a heuristic runner.
  - _Boundary: LegacyClassifierAdapter, ScreeningOrchestrator, OnDevicePipeline_
  - _Requirements: 1.1, 1.6, 5.1, 5.2, 9.6_

- [ ] 2.2 Delete heuristic graders and fabrication; establish the no-substitution value contract
  - Remove both non-model runner implementations and the synthesized probability/confidence/margin block; the post-inference path converts only the runner's own output through the shared derivation from 1.2, and runner output fields become non-null so an unavailable value can never be encoded and then backfilled.
  - Failure wording and mapping are preserved: preparation or inference exception → existing unavailable record with its reason and no backend; output-validation failure stays fail-closed through the existing evaluator into the withheld state.
  - Gate order, borderline logic, rejection messages and every frozen threshold expression remain byte-identical; no threshold or clinical claim is added or changed, and unresolved semantic items stay recorded rather than decided here.
  - Observable completion: a repo-wide search of the app's library code finds no heuristic runner class, no luminance-ratio computation and no synthesized value literal; the app compiles and existing suites stay green.
  - _Depends: 1.2, 2.1_
  - _Boundary: model_runner.dart runner implementations, DrModelOutput contract, ScreeningOrchestrator_
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 2.1, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 9.1, 9.2, 9.4, 9.5, 9.6_

- [ ] 2.3 Honest readiness, device-boundary status, and interpreter lifecycle
  - Readiness memoizes only success: a failed initialization reports not-ready and is retried on the next analysis instead of latching to success — one attempt per analysis invocation, no retry loop.
  - The device analysis stamps the result with its derived status (clean grade → preliminary; failure codes → unavailable or withheld; quality rejection → none) and the truthful backend, null when no model ran.
  - Add disposal that closes the interpreter through the runner chain.
  - Observable completion: two consecutive readiness checks after a failed initialization both report not-ready and analysis returns no grade; a gate-passing image yields preliminary with the canonical backend; after disposal the classifier reports not-ready.
  - _Depends: 1.1, 2.1_
  - _Boundary: OnDevicePipeline_
  - _Requirements: 2.1, 2.2, 6.1_

- [ ] 2.4 (P) Server results carry truthful status; confirmations never enqueue offline duplicates
  - The analysis call gains an opt-out for offline enqueueing, default unchanged for every existing caller, so a failed confirmation attempt cannot create a duplicate pending entry.
  - Server-produced models are stamped with their derived status: clean server result → service-produced; error and offline fallbacks → unavailable or withheld, never confirmed.
  - Observable completion: the confirmation path invokes the analysis with enqueueing disabled — asserted by 4.5's recording fake on the captured call, so a failed confirmation cannot create a duplicate pending entry — and a clean server result model reports service-produced with the server's own backend.
  - _Depends: 1.1_
  - _Boundary: ApiService_
  - _Requirements: 2.5, 5.1, 5.3, 6.4_

- [ ] 3. Integration: confirmation sequencing and truthful display
- [ ] 3.1 One connectivity-gated confirmation attempt in the analysis flow, plus flow-screen lifecycle
  - After a preliminary on-device result: probe connectivity; when reachable and a configured service exists, request confirmation for the same captured image with enqueueing disabled, then merge by equal DR grade into confirmed or disagreed; unreachable, timeout, error, unregistered-patient 404 and offline-fallback outcomes all leave preliminary untouched.
  - Non-preliminary results skip confirmation; the local-null server fall-through behaves exactly as today; failure states are never laundered through the confirmation step.
  - Exactly one shared-state write, before navigation; pipeline and API dependencies are injectable with production defaults; the flow screens dispose the pipeline they own.
  - Observable completion: with a reachable fake service there is exactly one confirmation request and the result is labelled confirmed or disagreed; with a failed probe or server error the result still reads preliminary; a gate-passing capture invokes the device grader.
  - _Depends: 1.1, 2.3, 2.4_
  - _Boundary: FlowAnalysisScreen, FlowCaptureScreen_
  - _Requirements: 5.3, 6.2, 6.3, 6.4, 6.6_

- [ ] 3.2 (P) Every result view shows the true backend and the honest status
  - Backend label: recognised identities render as today (device id → on-device wording, simulated → simulation warning, server ids as-is); missing or unrecognised → explicit unknown, never an assumed identity.
  - Status badge from the derived status: preliminary → the existing awaiting-specialist badge with awaiting-clinician-sign-off copy (the existing specialist verdict remains the sign-off gate); confirmed or produced → verified style naming the confirming backend; disagreed → warning naming both grades; unavailable or withheld → existing error/uncertain rendering; null status keeps today's rendering exactly. Offline and error visual precedence is unchanged.
  - No copy added or changed describes the score distribution as a probability or a calibrated or clinically validated quantity.
  - Observable completion: models in each state render the expected badge and label, an unknown backend renders the unknown label on all four result views, and no grade is presented as final while preliminary.
  - _Depends: 1.1_
  - _Boundary: Result screens_
  - _Requirements: 2.2, 2.3, 3.5, 3.6, 5.1, 5.2, 5.4, 5.6, 6.1, 6.5, 6.6, 9.3_

- [ ] 4. Validation: machine-checked evidence
- [ ] 4.1 (P) Status derivation and confirmation-merge tests
  - Cover every derivation branch including the four named acceptance states, quality-rejection → none, and the merge cases: agreement, disagreement, and server error or offline or missing grade → no confirmation; copy-on-change leaves the original untouched.
  - Observable completion: the new model-layer test files pass under the Flutter test runner and assert each named state maps to its expected status.
  - _Depends: 1.1_
  - _Boundary: model status tests_
  - _Requirements: 5.3, 6.3, 6.4, 6.6, 8.5_

- [ ] 4.2 (P) Fail-closed and no-substitution unit tests
  - Classifier failure paths (initialization failure, use before initialization, wrong input size) cannot yield a grade; a grader exception produces the unavailable record with null prediction, null confidence and the preserved reason, proving nothing reaches the confidence gate; the score-vector factory rejects malformed vectors instead of fabricating a result; spy output derives confidence as the max score and margin as top-1 minus top-2 exactly; gate-failing images never invoke the grader.
  - The composed analysis contains no synthesized probability literal — the behavioural half of 8.1, whose source-grep half lives in 4.7.
  - Observable completion: the new classifier and orchestrator test files pass and their assertions prove no synthesized value can reach a gate and no grade exists after failed initialization.
  - _Depends: 2.2, 2.3_
  - _Boundary: dr_classifier tests, screening_orchestrator tests_
  - _Requirements: 1.1, 1.2, 1.5, 2.1, 2.4, 2.6, 3.1, 3.2, 3.4, 4.1, 4.2, 4.3, 8.1, 8.2, 8.3_

- [ ] 4.3 (P) Readiness-retry and stored-accuracy tests
  - Failed readiness is not latched (two checks both fail and analysis returns no grade); default wiring asserts the canonical device identity; insert-then-read round-trips backend and status; status-less legacy rows remain readable after the migration.
  - Observable completion: the new pipeline and storage test files pass under the Flutter test runner.
  - _Depends: 1.3, 2.3_
  - _Boundary: OnDevicePipeline tests, LocalStore tests_
  - _Requirements: 2.1, 5.5, 6.7, 7.1, 7.3, 8.2_

- [ ] 4.4 (P) Live screening path integration test
  - Real fixture bytes through the composed device pipeline with an injected spy grader: a gate-passing image invokes the grader exactly once and yields a preliminary result with the canonical backend; a gate-failing fixture never invokes it; existing quality-gate and parity tests stay untouched and green.
  - Observable completion: the new integration test passes alongside the unchanged gate suites.
  - _Depends: 2.1, 2.2, 2.3_
  - _Boundary: screening path integration test_
  - _Requirements: 4.1, 4.2, 4.3, 4.6, 8.4_

- [ ] 4.5 (P) Confirmation-flow widget tests
  - With injected fakes: a reachable service produces exactly one confirmation request and a confirmed status, and the recording fake asserts that request was made with offline enqueueing disabled; a failed probe produces no request and leaves preliminary; a server error leaves preliminary; a gate-passing capture invokes the device grader.
  - Observable completion: the new widget test passes with no real network and no real model interpreter.
  - _Depends: 3.1_
  - _Boundary: FlowAnalysisScreen test_
  - _Requirements: 6.2, 6.3, 6.4, 8.4_

- [ ] 4.6 (P) Status and backend rendering tests
  - Pump the flow result view for each named state and assert badge and label text; unknown-backend models render the unknown label on all four result views; a confirmed view names the confirming backend; preliminary shows the sign-off wording.
  - Observable completion: the new rendering test passes.
  - _Depends: 3.2_
  - _Boundary: result_rendering_test.dart_
  - _Requirements: 2.2, 5.1, 5.2, 5.4, 5.6, 6.1, 6.5, 8.5_

- [ ] 4.7 CI source gate and full regression evidence
  - Add the banned-pattern grep step to the flutter job after the privacy gate and before static analysis, covering the deleted heuristic runner classes, the luminance computation and the fabrication literals; violations print and fail the job.
  - Run and record real results: full Flutter test suite (existing plus new), static analysis (0 issues), Python suite (119 passed + 127 subtests); verify the frozen threshold constants are unchanged and the working tree shows only the planned files modified, with no commits made.
  - Observable completion: the gate step exists and passes on the current tree (its pattern set finds nothing), the three in-scope suites (`flutter test`, `flutter analyze`, `pytest -q tests`) are reported with their actual pass counts, the root-level `pytest` collection failure (`matplotlib` in `external/`) is documented as pre-existing and out of scope, and any failing in-scope check is reported as a failure rather than completion.
  - _Depends: 2.2_
  - _Boundary: CI source gate_
  - _Requirements: 4.4, 4.5, 4.6, 7.2, 7.4, 7.5, 7.6, 8.1, 8.6, 8.7, 9.1, 9.2, 9.3, 9.4_

## Implementation Notes
- Task 1.1: `deriveResultStatus` returns `ScreeningResultStatus?` (nullable) — design.md's contract sketch (line ~442) shows non-nullable, but design.md:455, the Data-Models invariant (d), and the task text all require null for quality/decode rejections. Do NOT "fix" the signature back to non-nullable in later tasks.
- Process: implementer status reports for behavioral tasks must include `RED_PHASE_OUTPUT`; the 1.1 reviewer compensated with its own mutation testing. Keep in mind for 1.2+.
