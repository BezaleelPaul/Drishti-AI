# Brief: screening-ux-consolidation

## Problem
The application ships three complete parallel screening flows and duplicate model families, so every behavioral fix must be applied up to three times and it is ambiguous which flow is the product. Verified: the **Figma 7-step flow** (`lib/screens/flow/*`), the **Classic flow** (`checkin_screen.dart` → `quality_gate_screen.dart` → `results_screen.dart`), and the **Integrated 3-step flow** (`integrated_screening_flow.dart` → `patient_checkin_screen.dart` → `camera_capture_screen.dart` → `screening_result_screen.dart`), all reachable from the drawer (`figma_drawer.dart:98-127`). Duplicates: `Patient` vs `PatientModel`, `ScreeningResult` vs `ScreeningAnalysisModel`, three intake screens, three capture paths, three result screens, and `ApiService.registerPatient(dynamic)` duck-typing all three models (`api_service.dart:123-145`).

Around this sit three reliability and equity gaps: there is **no global error handling** (no `runZonedGuarded`, `FlutterError.onError`, `PlatformDispatcher.onError`, `ErrorWidget.builder`, or crash reporting anywhere in `lib/`), so field failures are invisible; accessibility is thin (one `Semantics` site at `scanner_view.dart:127`, zero `MediaQuery`/text-scaling usage, 9–11px text at `Colors.white24/38`, and **12 screen files with no `tr()` at all** including the clinical `camera_capture_screen`, `quality_gate_screen`, `results_screen`, `screening_result_screen`, `checkin_screen`, `consent_screen`, `patient_checkin_screen`); and demo PHI is prefilled in a production path (`patient_checkin_screen.dart:26-30`, contradicting the stated policy at `checkin_screen.dart:16-17`).

## Current State
- **Navigation**: Navigator 1.0, imperative `Navigator.push(MaterialPageRoute(...))` at 20+ sites, no router package, `MaterialApp` with only `home:` (`main.dart:63-68`).
- **State management**: no Provider/Riverpod/Bloc; `setState` in 22 files; only language state is centralized (`LangScope`/`LangController`, `l10n/lang_scope.dart:17,51`); cross-step `FlowState` is a mutable plain class mutated by child screens (`flow_state.dart:7-27`, `flow_capture_screen.dart:52,115-116,141`); two singletons (`OfflineQueueService._instance`, `LocalStore._instance`).
- **Localization**: custom 5-language map (`app_strings.dart` en/kn/hi/te/ta, ~185 keys) but header says "dashboard flow" only (`app_strings.dart:1-3`); `tr()` used in 15 files.
- **Error handling**: ~50 try blocks, ~18 swallowed `catch (_)`, including a fully empty one at `flow_capture_screen.dart:57`; 30 user-facing snackbars.
- **Debt signals**: zero TODO/FIXME comments (so nothing is tracked), largest files are `app_strings.dart` (928) and `api_service.dart` (~890) — near the 800-line project ceiling.
- **Branding inconsistency**: package `netra_ai_mobile` (`pubspec.yaml:1`), title "Netra-AI" (`main.dart:64`), drawer brand "Drishti-AI" (`figma_drawer.dart:44`).

## Desired Outcome
Exactly one screening flow is reachable in a normal build, backed by one patient model and one result model. Every unexpected error is caught globally and produces a visible, recoverable state instead of a white screen. Clinical screens are localized, text scales with system settings, and key actions carry semantic labels. Demo PHI never appears prefilled in a capture path.

## Approach
Declare the Figma 7-step flow canonical (decision already taken), move Classic and Integrated behind a debug-only entry point or remove them, unify `Patient`/`PatientModel` and `ScreeningResult`/`ScreeningAnalysisModel` behind single models with explicit JSON serialization, and narrow `registerPatient` to a typed signature. Add a global error boundary (`runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` + a user-facing error screen that never leaks stack traces) writing to a local, non-PHI crash log. Then a focused accessibility pass: port `tr()` to the 12 untranslated screens, introduce text scaling and semantic labels on primary actions, raise the low-contrast HUD text, and remove the prefilled demo patient. Defer a router or state-management migration — it is not required to fix any of the above and would be a risky rewrite.

## Scope
- **In**: single canonical flow with the other two demoted or removed; unified patient/result models and a typed registration API; global error boundary with a safe user-facing failure state and local non-PHI crash log; localization of the 12 untranslated screens; text scaling, semantic labels and contrast fixes; removal of prefilled demo PHI; consistent product naming.
- **Out**: adopting go_router, Provider, Riverpod or Bloc; visual redesign or new screens; a11y audit beyond the listed gaps (no screen-reader certification); crash-reporting SaaS; changes to the ML, sync or API layers.

## Boundary Candidates
- Flow retirement (which screens stay reachable)
- Model unification (one patient, one result)
- Global error boundary and failure presentation
- Localization / scaling / semantics pass

## Out of Boundary
- The inference and abstention logic inside those screens (`on-device-inference-integrity`, `prediction-consensus`) — this spec moves and unifies screens, it does not change what a grade means.
- Grad-CAM rendering decisions (`explainability-truthfulness` owns the overlay honesty fixes; coordinate edits to `flow_result_screen.dart` and `results_screen.dart`).
- Offline queue behavior (`offline-record-durability`).

## Upstream / Downstream
- **Upstream**: `on-device-inference-integrity` (this spec lands after it so screen edits are not rebased twice), `l10n/app_strings.dart`, existing `lib/screens/**`.
- **Downstream**: all other specs benefit from there being one flow to test; `test-ci-coverage-gate` hosts new widget tests for the surviving flow.

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `explainability-truthfulness` edits three of the same screens; `prediction-consensus` rewrites `flow_analysis_screen.dart`. Sequence this spec last among the P2 work to avoid conflicting edits.

## Constraints
- Existing 57 Flutter tests must stay green; tests referencing retired screens must be updated deliberately, not deleted to make the suite pass.
- Removal of a flow requires confirmation that `demo_rehearsal.py` and the drawer entry points still work.
- No new dependencies — in particular, no router or state-management package.
- No PHI may appear in crash logs; the crash log must store type/message/stack only, never payload fields.
- Prefilled demo data must be removed, not merely hidden.
