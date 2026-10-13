# Brief: prediction-consensus

## Problem
When the on-device grader and the server grader both produce a result for the same image, nothing compares them. The current control flow is strictly sequential and self-disabling: `flow_analysis_screen.dart:95-131` runs on-device first and calls the server **only** when the local result is null (`:104-111`) or throws (`:113-116`), and because the current default runner never fails (`model_runner.dart:60-62`), the server path is effectively unreachable in practice. A repo-wide search for cross-check, consensus, disagreement or conflict resolution between device and server returns no relevant matches. So two sources of truth exist with no agreement check, no disagreement handling, and no rule about which one an operator sees.

This is a safety gap, not just an engineering one: the system already treats *unresolved conflicts as a reason to stop* elsewhere (low confidence → `AI_LOW_CONFIDENCE`, "no automated result released", `src/pipeline/router.py:352-359`), but device-vs-server divergence is the one conflict it never examines.

## Current State
- **Sequential, non-comparing flow**: `flow_analysis_screen.dart:95-131` as described; server results are never persisted alongside device results for later comparison.
- **No shared contract for comparison**: `DrModelOutput` (`model_runner.dart:9-29`) and `DRClassificationResult` (`pipeline_schema.dart:136-174`) have different field semantics — notably `probabilities` is nullable on the Dart side and fabricated when null (`screening_orchestrator.dart:224-230`), so a naive comparison today would be meaningless.
- **Existing abstention vocabulary to reuse**: `AI_LOW_CONFIDENCE`, "no automated result released" (`router.py:352-359`), mandatory clinician review for referable grades (`router.py:328-337`), always-flag for grades 3/4 (`confidence.py:109-114`), the Dart-side `uncertainty > 0.4` abstain (`screening_orchestrator.dart:256`), and the fail-closed `validate()` (`pipeline_schema.dart:153-173`).
- **Offline reality**: the app is offline-first, so "server unavailable" must be a normal state, not an error — consensus can only be evaluated when connectivity allows.
- **Prerequisite**: both sides must produce comparable, real predictions — which depends on `on-device-inference-integrity` and `preprocessing-parity`.

## Desired Outcome
When both a device grade and a server grade exist for the same image, the system compares them and acts deterministically: agreement → release under the normal rules; disagreement → withhold the automated result and escalate to a qualified human reviewer, with both grades and their confidences preserved for audit. When only one side is available, the result is explicitly labelled as single-source. Nothing silently picks a winner.

## Approach
Define a single comparison contract (grade equality, referability agreement, and a confidence/margin tolerance) as a shared, tested pure function on both stacks, reusing the existing abstention vocabulary rather than inventing new codes. Change `flow_analysis_screen` from a fallback chain into an explicit two-source state machine with three outcomes — `AGREE`, `DISAGREE`, `SINGLE_SOURCE` — and render each honestly in the result screens. Persist both predictions with the record so disagreement is auditable and back-sync-able. When the server is unreachable, show `SINGLE_SOURCE (device)` and keep the preliminary labeling introduced by `on-device-inference-integrity`. All disagreements route to the existing clinician-review flow rather than a new mechanism.

## Scope
- **In**: a documented and unit-tested cross-source comparison contract; a three-outcome state machine replacing the null/throw fallback chain; withholding and escalation on disagreement using existing abstention codes; persistence of both predictions for audit; honest single-source labeling when offline; tests covering agree/disagree/offline/one-side-invalid.
- **Out**: deciding *which* source is authoritative when they disagree (the answer is neither — it escalates); model or threshold changes; server-side router changes beyond emitting a comparable result; the offline queue and sync mechanics; explanation comparison (Grad-CAM is not compared).

## Boundary Candidates
- Comparison contract (pure, shared, tested)
- Outcome state machine in the analysis flow
- Escalation routing (reuse clinician review)
- Audit persistence of both predictions

## Out of Boundary
- Making each source trustworthy — that is `on-device-inference-integrity` and `preprocessing-parity`.
- Getting server results reliably in the first place — `offline-record-durability` and `sync-reliability`.
- Changing abstention thresholds (`0.60` / `0.15` / `0.4`) — these are shared policy and must not be forked.

## Upstream / Downstream
- **Upstream**: `on-device-inference-integrity` (real device prediction), `preprocessing-parity` (comparable tensors), `src/pipeline/confidence.py` and `router.py` (existing abstention codes), `pipeline_schema.dart` fail-closed validation.
- **Downstream**: `screening-ux-consolidation` (the screens this state machine renders into); `test-ci-coverage-gate` (hosts the contract tests); audit requirements from `sync-reliability`.

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: must land after `preprocessing-parity`; shares `screening_orchestrator.dart` and `flow_analysis_screen.dart` with `on-device-inference-integrity` and `screening-ux-consolidation` — sequence it after both to minimize rebase conflict.

## Constraints
- Must work with zero connectivity: offline is the normal case, never an error state.
- Disagreement must never resolve to "use the more confident one" or "average them" — it escalates to a human.
- No new abstention codes unless existing ones cannot express the state; any new code must be added to both stacks and to the stable `error_code` contract asserted by `tests/red_team/test_safety_invariants.py`.
- Existing green suites must stay green.
- The comparison must be deterministic and unit-testable without a device or network.
