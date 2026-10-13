# Brief: test-ci-coverage-gate

## Problem
The project's stated reliability goal is not currently enforced. CI uses `unittest discover` (`.github/workflows/ci.yml:43,47,53`), which silently skips every pytest-style test — including all 15 de-identification/PHI contract tests in `tests/integration/test_deidentified_sync.py` and all 10 API contract tests in `tests/integration/test_api_contracts.py`. Live-verified: `python -m unittest tests.integration.test_deidentified_sync` → `Ran 0 tests`. The most safety-critical security surface in the repository is therefore verified only when someone happens to run pytest locally. Separately, no coverage measurement exists anywhere: `pyproject.toml` has no `[tool.coverage]`, CI has no coverage step, and neither `pytest-cov` nor `coverage` is installed in the venv. Root-level `pytest` fails collection entirely (13 `ModuleNotFoundError: matplotlib` from vendored `external/`), so `make test` fails too.

## Current State
Verified by running the suites during discovery:
- `pytest -q tests` → **119 passed, 127 subtests passed** (142.6 s).
- `flutter test` → **57 passed**; `flutter analyze` → **0 issues**.
- `pytest -q` at repo root → **13 collection errors**, all from `external/fundus_image_toolbox/**`.
- `verify_complete_system.py` → 10/10 subsystems, 17.8 s (docs claim < 1 s).
- Zero coverage config/step/plugin anywhere.
- Untested safety-critical modules (0 references in `tests/`): `src/reporting/fhir_exporter.py`, `src/reporting/pdf_generator.py`, `src/clinical_risk/risk_model.py`, `src/image_io.py`, `evaluate_calibration.py`, `operating_point_sweep.py`.
- Untested Flutter modules (0 references in `flutter_app/test/`): `dr_classifier.dart`, `on_device_pipeline.dart`, `model_runner.dart`, `screening_orchestrator.dart`, `api_service.dart`, `db/local_store.dart`, and all `screens/flow/*`.
- Existing coverage that works well and must be kept: red-team corpus sweep (64 subtests), domain-gate red team, safety invariants, adversarial Flutter parity tests.

## Desired Outcome
A push or PR that breaks a safety invariant, a PHI contract, or the on-device pipeline fails CI. Coverage is measured on every run and a floor is enforced so it cannot silently regress. Root `pytest` and `make test` work.

## Approach
Three slices, each independently mergeable: (1) replace the three `unittest discover` steps with a single `pytest tests` invocation so all 119 tests run in CI — this alone closes the biggest hole; (2) add coverage measurement (`pytest --cov` with `pyproject.toml` config), publish the number, and set a floor slightly below current measured coverage so it gates regressions without blocking; (3) backfill tests for the highest-risk untested modules, prioritized by safety: on-device ML path first (the subject of `on-device-inference-integrity`), then `fhir_exporter.py` and the calibration scripts. Fix root collection by excluding `external/` so `make test` is usable.

## Scope
- **In**: CI runs the full pytest suite; coverage measurement plus an enforced floor; pytest collection fix for `external/`; backfill tests for the untested safety-critical modules listed above; a documented single command for the full gate.
- **Out**: reaching a specific coverage percentage as a goal in itself; performance/load testing; UI screenshot or E2E device farms; rewriting existing passing tests; adding new test frameworks beyond `pytest-cov`/`coverage`.

## Boundary Candidates
- CI execution fix (what actually runs on push/PR)
- Coverage measurement and gating configuration
- Python backend test backfill (reporting, clinical risk, calibration)
- Flutter on-device ML test backfill

## Out of Boundary
- Changing application behavior to make a test pass.
- Deleting or weakening the existing red-team and adversarial corpora tests.
- Test infrastructure beyond this repo (external monitors, dashboards).

## Upstream / Downstream
- **Upstream**: `.github/workflows/ci.yml`, `pyproject.toml`, `Makefile:27-29`, the existing `tests/` tree.
- **Downstream**: every subsequent spec in this roadmap uses this gate as its proof of "did not break existing functionality"; `on-device-inference-integrity` and `preprocessing-parity` add tests here.

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `claims-evidence-fidelity` (hosts the banned-figure regression test, which lives in this suite); `on-device-inference-integrity` and `preprocessing-parity` (contribute the on-device tests); `offline-record-durability` (contributes record-lifecycle tests).

## Constraints
- Must keep running on the existing ubuntu+windows matrix and Python 3.11 without adding heavyweight services.
- Coverage floor must be set from a measured baseline, never invented.
- No new dependencies beyond the coverage tooling itself.
- CI runtime must not balloon; the current suite already takes ~143 s locally.
