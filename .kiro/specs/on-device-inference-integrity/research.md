# Gap Analysis — on-device-inference-integrity

> Status: requirements generated but **not yet approved** (`spec.json` → `approvals.requirements.approved: false`). Analysis proceeds to inform approval/design.
> Steering: `product.md`, `tech.md`, `structure.md` are **absent** (`.kiro/steering/` contains only `roadmap.md`). Context sourced from discovery findings and direct source inspection.
> Evidence base: two read-only codebase surveys of the inference path, result rendering, and test/CI conventions. Every claim carries `file:line`.

---

## 1. Current State Investigation

### Reusable assets already present

| Asset | Location | Why it matters |
|---|---|---|
| Injectable runner interface | `model_runner.dart:32-39` — `DrModelRunner { modelId, modelVersion, initialize(), predict(img.Image), dispose() }` | Provenance and failure can be observed at a single seam |
| Working real inference | `dr_classifier.dart:22-87` — `Interpreter.fromAsset` `:43`, `classify()` `:59-81`, throws `StateError` on unload `:47` / uninitialized `:62` | The correct implementation exists; it is simply never constructed |
| Bridge adapter | `screening_orchestrator.dart:13-55` (`LegacyClassifierAdapter`, resizes to 224 `:28-40`, `modelId 'build_a_legacy'` `:18`) | Already maps the real classifier onto the runner interface |
| DI seams | `ScreeningOrchestrator({modelRunner, classifier, qualityGate})` `:59-64`; `OnDevicePipeline({modelRunner, classifier})` `:14-18` | Fake/real runners injectable without production changes |
| Fail-closed quality path | `screening_orchestrator.dart:86-221` — decode `:86-97`, gate `:116-120`, `BAD` `:123-158`, `BORDERLINE` `:161-200`, runner exception → `aiUnavailable` `:204-221` | R2/R4 largely already satisfied at this layer |
| Validation fail-closed | `pipeline_schema.dart:153-173` (`validate()` rejects NaN, wrong length, confidence≠max(probs)); `dr_classifier.dart:91-101` throws on non-finite | Existing guardrails to build on |
| Confirmation capability | `api_service.dart:669-739` `analyzeRetinaFull({imageBytes, patientId, eyeSide, ...})` accepts arbitrary bytes | R6 can request confirmation for an already-captured image **today** |
| Status vocabulary | `errorCode` codes (`aiUnavailable`, `aiLowConfidence`, `imgUngradable`…), `isOffline` `:162`, `isFromFallback` `:163`, `qualityPassed` `:134` | Partial status surface already rendered by all three result screens |
| Test conventions | `flutter_app/test/*` — package imports, single `group`, plain `expect`, no mocks; repo-root fixtures via `Directory('../test_samples/...')` (`adversarial_gate_parity_test.dart:10`, `phone_image_parity_test.dart:9`) | Proven idiom for both byte-built and corpus fixtures |
| Source-check precedents | `ci.yml:105-114` privacy grep-gate; `ci.yml:300-306` bundle grep-gate; `Makefile:27-29` `test` target | An automated source check has an established registration pattern |

### Dominant architecture constraints

- Layering is **screens → services → models** with no repository/domain layer; screens instantiate services directly (`flow_analysis_screen.dart:36-37`), so **the live path has no dependency injection**.
- One result slot: `FlowState.analysis` (`flow_state.dart:15`), assigned at `flow_analysis_screen.dart:161`. Result objects are never passed between screens — the whole `FlowState` is.
- All three result screens **re-derive UI state from `(drGrade, errorCode, modelBackend, isReferable)`** rather than reading a status field (`flow_result_screen.dart:82-85`, `results_screen.dart:170-180`, `screening_result_screen.dart:121-132`).

---

## 2. Requirement-to-Asset Map

Gap types: **Missing** = capability absent · **Constraint** = existing design limits the change · **Unknown** = research needed.

| Req | Area | Existing assets | Gap |
|---|---|---|---|
| 1 | On-device provenance | `DrModelRunner` interface `model_runner.dart:32-39`; `DrClassifierDart` `dr_classifier.dart:22-87`; `LegacyClassifierAdapter` `screening_orchestrator.dart:13-55`; asset declared `pubspec.yaml:95` | **Missing**: the default grader is constructed as `DrDetectRunner()` at two sites (`on_device_pipeline.dart:17`, `screening_orchestrator.dart:63`), whose `initialize()` only sets a flag (`model_runner.dart:60-62`) and whose `_inferOrdinalRegression` computes an R/G luminance ratio (`:153-163`). **Missing**: `BuildARunner` returns hard-coded `[0.70,0.15,0.08,0.04,0.03]` (`:202-210`). **Constraint**: `DrModelRunner.predict` takes `img.Image` while `DrClassifierDart.classify` takes a 224-byte RGB buffer — only the adapter bridges them |
| 2 | Fail-closed | Orchestrator fail-closed block `:86-221`; `StateError` on load failure `dr_classifier.dart:47`; `validate()` `pipeline_schema.dart:153-173` | **Missing**: `OnDevicePipeline.ensureReady()` sets `_initTried = true` **before** the try (`on_device_pipeline.dart:26-35`), so a failed initialization reports success on every later call — a **fail-open hazard** directly contradicting R2. **Missing**: no distinct operator-visible "model unavailable" state; `analyze()` returns `null` (`:100`) and callers fall through. **Constraint**: `DrClassificationResult` fields are non-nullable (`pipeline_schema.dart:145-149`) |
| 3 | Honest uncertainty | `ConfidenceEvaluatorDart` `confidence_evaluator.dart:12-76`; thresholds `quality_thresholds.dart:45-47`; 9 existing tests | **Missing (core defect)**: fabrication at `screening_orchestrator.dart:224-230` (probability vector), `:231` (confidence), `:237` (top2Margin). **Constraint / conflict**: the evaluator requires a non-null `DrClassificationResult`, so "treat as unavailable" cannot be expressed through the current type — either the type becomes nullable (ripples into `validate()` and 9 tests asserting exact behaviour) or the path short-circuits with an error code before the evaluator. **Unknown**: UD-5 `uncertainty > 0.4` gate at `:256` has no server counterpart |
| 4 | Preserved gates | `QualityGateDart.assess` before inference `:116-120`; domain check inside `quality_gate.dart:28-37`; tests `quality_gate_test.dart` (5), `adversarial_gate_parity_test.dart`, `phone_image_parity_test.dart` | **Constraint**: none blocking — this is the strongest existing area. **Constraint**: operator "proceed anyway" affordances live in screens outside the orchestrator and must not be disturbed |
| 5 | Backend identity | `modelBackend` flows record → analysis model (`screening_orchestrator.dart:287` → `on_device_pipeline.dart:148` → `screening_models.dart:157`) | **Missing**: UI recognises only `'tflite-fp32'` and `'simulated'` (`flow_result_screen.dart:44-48`, `results_screen.dart:172`, `screening_result_screen.dart:132`), while the live path writes `build_a_legacy` / `drdetect_ordinal` / `build_a` — **the displayed label never matches what ran**. **Missing (false provenance)**: `ScreeningRecordDart.modelBackend` defaults to `'tflite-fp32'` (`pipeline_schema.dart:209`) and the DB defaults the same (`local_store.dart:116,210`), so quality-gate-only rejections are labelled as if inference ran. **Missing**: no test asserts label correctness |
| 6 | Preliminary vs confirmed | `analyzeRetinaFull` `api_service.dart:669-739`; `isOffline`/`isFromFallback`/`errorCode` rendered by all three screens | **Missing (largest gap)**: **no status field exists on any result model** — `ScreeningAnalysisModel` `screening_models.dart:138-178` has no preliminary/confirmed notion; `FlowState` `flow_state.dart:8-26` has one `analysis` slot; `flow_analysis_screen.dart:104-110` short-circuits so **only one source ever occupies it**. **Missing**: no second payload for side-by-side results (R6 AC6). **Unknown**: whether `FigmaStatus` (`figma_theme.dart:25-67`) is an acceptable home or a semantic mismatch. **Constraint**: server confirmation requires the patient be registered server-side (`api_service.dart:114-118`) |
| 7 | Record & workspace integrity | `recordScreening` has **zero callers** (`local_store.dart:191-248`); `dispose()` never called | **Constraint**: dirty working tree (staged `demo/*`; modified `flutter_app/lib/**`, `pubspec.*`, `test/widget_test.dart`; untracked `.kiro/`, `AGENTS.md`, `flutter_app/lib/screens/splash/`, `widgets/{futuristic,scanner}/`, 2 new tests). **Constraint**: DB column `model_backend NOT NULL DEFAULT 'tflite-fp32'`. **Low blast radius**: the dead persistence writer means persistence changes cannot break current behaviour |
| 8 | Verifiable tests | Test idioms established; `../test_samples` fixture access proven in `flutter test`; two CI grep-gates as exemplars | **Missing**: **no test imports any file this spec changes** (`flutter_app/test/` grep = 0 hits for `on_device_pipeline`, `screening_orchestrator`, `model_runner`, `dr_classifier`, and the four result screens) — every required test is new. **Missing**: no Dart source-scan test exists anywhere ("not found"). **Unknown**: success-path unit test of `DrClassifierDart` is **impossible today** — `Interpreter.fromAsset` is hard-wired (`dr_classifier.dart:43`) and `_interpreter` is private (`:31`); only the failure path is testable, via the injectable `assetPath` (`:23`) |
| 9 | Clinical honesty | Threshold constants `quality_thresholds.dart:45-47`; `DrGrade.isReferable => >= 2` `pipeline_schema.dart:47`; `kReferableMassThreshold` used `on_device_pipeline.dart:119-125`; 9 tests pin exact flag strings | **Constraint**: any threshold edit breaks `confidence_evaluator_test.dart` — an effective guardrail. **Unknown**: UD-2 referable-score semantics (`on_device_pipeline.dart:119-125`, `LegacyClassifierAdapter` `:45`) must not be reused until verified |

### Complexity signals

Not CRUD. This is **fail-closed workflow logic + cross-layer provenance** with a UI status surface: moderate algorithmic content, low external integration (one existing confirmation call), high correctness sensitivity.

---

## 3. Implementation Approach Options

### Option A — Extend existing components

**Change set:** swap the two default-runner constructions to `LegacyClassifierAdapter(DrClassifierDart())`; delete `BuildARunner` and the fabricator at `:224-237`; fix `ensureReady`; remove the misleading `modelBackend` default; add a status value to `ScreeningAnalysisModel`; call `analyzeRetinaFull` after the on-device result; align the three screens' label logic; add tests + a CI grep-gate.

- **Files touched:** ~10 production (`on_device_pipeline`, `screening_orchestrator`, `model_runner`, `pipeline_schema`, `screening_models`, `flow_analysis_screen`, 3 result screens, `flow_state`) + ~5 new tests + `ci.yml`.
- ✅ Reuses every existing seam (DI, adapter, fail-closed block, confirmation call) — lowest novel surface.
- ✅ Smallest diff; no new architectural concepts.
- ❌ `screening_orchestrator.dart` (291 lines) absorbs more responsibility; provenance/status logic stays spread across three screens.
- ❌ Live screens hard-wire `OnDevicePipeline()` (`flow_analysis_screen.dart:37`, `flow_capture_screen.dart:30`), so "live path invokes the real grader" is only testable at pipeline level unless a screen-level seam is added.

### Option B — Create new components

**Change set:** introduce a dedicated provenance/status type (e.g. a result-status value object covering preliminary / confirmed / unavailable / withheld), a confirmation coordinator owning the request and the status transition, and a named bundled-model runner; screens read one provenance object instead of re-deriving from four fields.

- ✅ Single responsibility; status/backend/confirmation in one testable place — best fit for R5+R6, which currently have **no** home.
- ✅ Makes the automated source check trivial (one module to scan).
- ✅ Removes duplicated label derivation across three screens.
- ❌ More files to navigate; duplicates vocabulary already expressed by `errorCode` / `isFromFallback` / `qualityPassed` — risk of two competing status models.
- ❌ Requires touching `flow_state.dart`, `screening_models.dart` and the dashboard mapping together; larger blast radius on `dashboard_feed_mapping_test`.

### Option C — Hybrid (phased)

- **Phase 1 (this spec):** extend — swap defaults, delete fabrication and `BuildARunner`, fix `ensureReady`, remove the false `modelBackend` default, **and introduce exactly one new small type for result status**, because the investigation shows no field exists to hold it. Add the confirmation call and align label rendering. Land tests + source gate in the same change.
- **Phase 2 (deferred):** collapse the duplicated per-screen label derivation and consolidate provenance handling — belongs to `screening-ux-consolidation` and `prediction-consensus` per the boundary context.
- ✅ Matches existing patterns while admitting that R5/R6 have no existing home.
- ✅ Staged: Phase 1 alone satisfies all nine requirements; Phase 2 is a refactor, not a dependency.
- ❌ Two-phase coordination; a temporary period where status exists as a type but label derivation is still duplicated.

---

## 4. Implementation Complexity & Risk

- **Effort: M (3–7 days).** Existing DI seams, an already-correct classifier, and an already-fail-closed orchestrator remove most unknowns; but R6 requires a brand-new status surface across 4 files, and every test in R8 is new. R6 alone is roughly half the work.
- **Risk: Medium.** Justification: familiar architecture and no new dependencies, but four concrete hazards — (1) adding a field to `ScreeningAnalysisModel` ripples into `dashboard_feed_mapping_test.dart` and `figma_dashboard_screen.dart:712-725`; (2) the success path of the real model is **not unit-testable without a production seam**; (3) fixing the `ensureReady` fail-open bug changes offline/retry behaviour; (4) nine existing tests pin exact confidence flag strings, so any threshold-adjacent edit fails loudly.

---

## 5. Research Needed (defer to design phase)

1. **Test seam for real inference.** `Interpreter.fromAsset` is hard-wired (`dr_classifier.dart:43`) and `_interpreter` is private. Options: add an interpreter factory/`fromBuffer` seam, test through `LegacyClassifierAdapter`/orchestrator with a fake runner and reserve asset-path loading for one integration test, or rely on the injectable `assetPath` (`:23`) with the real bundled asset. Failure testing already works today via a bogus `assetPath`.
2. **Status field home and shape.** Decide between extending `ScreeningAnalysisModel` vs a separate provenance object; and whether `FigmaStatus` (`figma_theme.dart:25-67`) is a semantic fit or a mismatch. Must also confirm no collision with server-provided status tokens (`figma_dashboard_screen.dart:712-725`) and with `dashboard_feed_mapping_test.dart`.
3. **Server confirmation contract.** Confirm what `/retinal/analyze` returns that identifies the response as server-produced (candidate: `model_backend` from `api/schemas.py`), and how a client-side "confirmed" status is derived without a server-provided status field. Also handle patient-not-registered (`api_service.dart:114-118`) and the 45 s timeout (`:42`).
4. **UD-2 referable semantics.** Whether the on-device path may report referability at all before `kReferableMassThreshold` (`on_device_pipeline.dart:119-125`) and `LegacyClassifierAdapter`'s `sum(p2..p4)` (`:45`) are verified.
5. **UD-5 uncertainty gate.** Keep, align, or remove `uncertainty > 0.4` (`screening_orchestrator.dart:256`) — thresholds are governed by Requirement 9.
6. **`ensureReady` retry policy.** Correcting the one-shot bug requires deciding the retry/backoff semantics for model initialization.
7. **Interpreter lifecycle.** `dispose()` exists (`dr_classifier.dart:83-87`) but is never called — decide ownership for low-memory devices.
8. **Source-check placement.** All three registration points have exemplars: a `ci.yml` flutter-job step modelled on the privacy gate (`ci.yml:105-114`), a `Makefile` target (`:27-29`), or a Dart test scanning `lib/` via `File('../lib/...').readAsStringSync()` (repo-root access already proven, but no source-scan precedent exists).
9. **`modelBackend` default removal.** Whether changing the DB column default (`local_store.dart:116,210`) needs a migration — currently low impact because `recordScreening` has no callers.

---

## 6. Recommendations for Design Phase

- **Preferred approach: Option C (Hybrid)** — extend the existing seams for everything that already has a home (runner selection, fabrication removal, fail-closed fix, gates), and introduce one new status type only for R5/R6 where the investigation proves no field exists. It is the only option that satisfies all nine requirements without either spreading status logic further across three screens (A) or building a parallel vocabulary (B).
- **Key decisions the design must make explicit:** the status type's shape and home; the canonical backend identifier; the test seam for real inference; whether unavailable confidence is expressed as a nullable type or an early error-code short-circuit (Requirement 3 vs the non-nullable `DrClassificationResult`).
- **Carry forward:** all nine Research Needed items; the four risk hazards; the test-coupling list (`confidence_evaluator_test` ×9, `quality_gate_test` ×5, `dashboard_feed_mapping_test`, `widget_test`) as the regression floor.
- **Sequencing note:** `preprocessing-parity` depends on this spec landing first; `prediction-consensus` consumes the status type introduced here. Coordinate `screening-ux-consolidation` so the three result screens are not edited twice.

---

## 7. Design-Phase Discovery Log (extension / light discovery)

> Consulted skills and guidance applied: `design-discovery-light` (extension-point analysis, dependency check, integration risk), `design-synthesis` (three lenses before drafting), `design-principles` (boundary-first, type safety, dependency direction, diagram rules), `design-review-gate` (mechanical + judgment checks before writing `design.md`).
> Three read-only sub-agent surveys returned findings summaries: (a) server confirmation contract, (b) status surface and test ripple, (c) test/CI seam. Steering `product.md`/`tech.md`/`structure.md` remain absent — context sourced from discovery findings and direct source inspection.

### Key survey facts that shaped the design

1. **Server contract has no status field.** `POST /retinal/analyze` returns `model_backend`, `dr_grade`, `is_referable`, `requires_human_review` but nothing that says "confirmed" (`api/schemas.py:142-215`). Server provenance is implied by `screening_id` prefix `SCR-` (`ai_bridge.py:228`); client fallback ids use `LOC-`/`TMO-`/`UNAV-` (`api_service.dart:276,307,339`). Confirmation must therefore be derived client-side by comparing `dr_grade` for the same image. Preconditions: `X-API-Key`, registered patient (404 otherwise, `retinal.py:129-133`), 45 s inference timeout (`api_service.dart:42`), `ping()` probe exists (`api_service.dart:103`).
2. **Status has no home; ripple is small.** `ScreeningAnalysisModel` has no status field and **no test constructs it** (grep = 0) — adding nullable fields `resultStatus` + `confirmation` breaks nothing. `FlowState.analysis` has one slot written only at `flow_analysis_screen.dart:161`. `recordScreening` (`db/local_store.dart:191-217`) has **zero callers**, so persistence accuracy can be fixed without behaviour change; DB column `model_backend NOT NULL DEFAULT 'tflite-fp32'` (`local_store.dart:116`) cannot change non-destructively.
3. **Seams verified.** DI exists at `OnDevicePipeline({modelRunner, classifier})` (`on_device_pipeline.dart:14-18`) and `ScreeningOrchestrator(...)` (`screening_orchestrator.dart:59-64`); `OnDevicePipeline.modelRunner` getter (`:21`) allows a wiring assertion; `ApiService({baseUrl, key})` is constructible for tests (`api_service.dart:69`); no mocking library exists and none is needed (hand-rolled fakes + `package:http/testing.dart` precedent, `referral_uplink_service_test.dart:21-22`). CI grep-gate exemplar at `ci.yml:105-114`, slot for new gate immediately after `:114`. Success path of `DrClassifierDart` cannot run under `flutter test` (platform-channel interpreter) — success coverage must run through the injectable `DrModelRunner` seam.

## 8. Design Synthesis Outcomes

**Generalization**
- R1+R2+R3 are one invariant: *a grade implies a completed `predict()` whose values are derived only from that execution*. Enforced once at the orchestrator post-predict block instead of three separate guards.
- R5+R6 are one concern: *identity and confirmation status travel with the result*. Generalized into one provenance surface (`resultStatus` + `confirmation` + canonical backend vocabulary) consumed by all four result-reading screens.

**Build vs. Adopt**
- Adopt `flutter_litert` + existing `DrClassifierDart` for inference (no new dependency).
- Adopt existing `ApiService.ping()` + `analyzeRetinaFull` for confirmation (no new endpoint, no new auth surface).
- Build only the status/confirmation vocabulary (nothing in the codebase holds it).
- Adopt the existing CI grep-gate pattern; adopt hand-rolled fakes (no mockito/mocktail).

**Simplification**
- Delete `DrDetectRunner` and `BuildARunner` outright — R1/R8.1 become type-level facts (the classes cannot be reached) instead of runtime guards.
- With the ordinal runner gone, `DrModelOutput.probabilities`, `referable` and `uncertainty` become required — the null branch that motivated fabrication ceases to exist.
- Confidence/margin/uncertainty become single pure derivations from the model's probability vector (one `DrClassificationResult.fromProbabilities` factory shared by `DrClassifierDart` and the orchestrator).
- No interpreter factory seam (failure path testable via `assetPath`, success path via the runner seam); no background confirmation state machine (one inline attempt — retries belong to `sync-reliability`).

## 9. Design Decisions Register (resolves Unresolved Decisions 1-5)

| # | Decision | Rationale / evidence |
|---|---|---|
| D1 | Canonical bundled-model backend id = `'tflite-fp32'` | Already the DB/local default and the only value all screens recognise (`pipeline_schema.dart:209`, `flow_result_screen.dart:48`); `LegacyClassifierAdapter.modelId` changes from `'build_a_legacy'` (`screening_orchestrator.dart:18`). Undeterminable → `'unknown'` (5.4/5.6). Server backends keep server values (`onnx_drdetect`, `keras`, `pytorch`). |
| D2 | Status surface = new module `lib/models/result_status.dart`: enum `ScreeningResultStatus {preliminary, serviceConfirmed, serviceDisagreed, serviceProduced, unavailable, withheld}` + `ServiceConfirmation` + pure `deriveResultStatus()` / `buildConfirmation()` | No field exists today (survey 2). `serviceProduced` keeps R2.5 literally satisfied: a server result shown after local failure is neither "on-device" nor "confirmed". `null` status = non-grading outcome (quality/decode rejection) — existing rejection UI owns it. |
| D3 | `ensureReady()` records success only; failure returns false and retries on next analysis call | Fixes fail-open hazard at `on_device_pipeline.dart:26-35`; bounded to one init attempt per user-initiated analysis (no backoff timer). |
| D4 | UD-2 referable: on-device keeps reporting referability unchanged (grade ≥ 2 mirrors server `schema.py:39-40`; mass ≥ 0.09 is the documented X-0 operating point, `pipeline_schema.dart:234-243`). Confirmation compares **`dr_grade` only** | The unverified comparators (`BuildARunner` 0.09 on fabricated probs, `DrDetectRunner` 1.5) are deleted with their runners. Agreement rule avoids coupling the confirmation decision to referable semantics. |
| D5 | UD-5: `uncertainty > 0.4` (`screening_orchestrator.dart:256`) retained unchanged; flagged for threshold governance outside this spec | R9.1/R9.2 forbid new or changed thresholds in this change. |
| D6 | UD-3 persistence: do **not** start persisting; `recordScreening` gains required `modelBackend` + `resultStatus` params and an additive nullable `result_status` column (schema version +1) | `recordScreening` has zero callers (`db/local_store.dart:191-248`); queue/retry/retention remain `offline-record-durability`'s boundary; accuracy-only per requirements boundary context. |
| D7 | UD-4 confirmation retry: exactly one inline attempt inside `_runAnalysis`, gated by `ping()`; failure never upgrades status; no auto-retry | Retries owned by `sync-reliability`. |
| D8 | Confirmation uses `analyzeRetinaFull(..., queueOffline: false)` — a new optional parameter (default `true`, non-breaking) so a failed confirmation cannot enqueue a duplicate offline entry | `analyzeRetina` auto-queues on socket failure (`api_service.dart:618-653`); queue semantics belong to other specs. |
| D9 | Test seam: no production change to `DrClassifierDart`; composition-root seams only — optional `pipeline`/`api` constructor params on `FlowAnalysisScreen` (defaults to production wiring) | Keeps `Interpreter.fromAsset` untouched; makes R8.4's live-path test possible without a platform interpreter. |
| D10 | Interpretation of R8.5 state names: preliminary → `preliminary`; service-confirmed → `serviceConfirmed`; service-unavailable → `unavailable` (no grade from anywhere) + backend `unknown`; withheld → `withheld` | Ties the acceptance wording to enum values explicitly. |
| D11 | R6.5 sign-off: preliminary renders the existing `FigmaStatus.awaitingSpecialist` badge with an explicit "awaiting clinician sign-off" label; the existing specialist verdict step (`FlowState.verdict`) remains the sign-off gate of record | No new navigation gate; flow structure already sequences result → specialist → referral. |

Carried risks from §4 remain: `ScreeningAnalysisModel` field addition (low — no test constructs it), success-path testability (solved by D9 + runner seam), `ensureReady` fix changes offline retry (deliberate, R2), nine pinned confidence-flag tests (regression floor — thresholds untouched).
