# Drishti-AI Roadmap — SIH2026 SIH26038

Living plan. Status legend: **Done** · **Now** · **Next** · **Blocked** (needs hardware/data/SDK) · **Ongoing** (never finished, worked in rounds).

## Phase 0 — Correctness & clinical honesty — **Done**
No fabricated outputs anywhere in the demo/API path: simulated backend is labeled and
flagged non-diagnostic (`model_backend` on every response); ungradable scans render
"not assessed" in PDF/FHIR/SMS/UI; bilateral grades run live inference; zero-leakage
gate (BAD ⇒ no DR grade) proven by tests.

## Phase 1 — Backend hardening — **Done**
API-key auth with roles, IP rate limiting, request caps, atomic verdicts, idempotent
`/sync` (same local ID ⇒ same screening ID), NULL-preserving referability, audit log,
WAL SQLite, prod-safe startup (refuses dev keys on LAN, loopback default).

## Phase 2 — Packaging & reproducibility — **Done**
Pinned requirements (CPU torch), aligned pyproject, non-root Docker image with tini,
`.dockerignore`, venv-aware Makefile, portable pptx builder, retention purge job.

## Phase 3 — Validation evidence — **Now**
| Item | Status | Note |
|---|---|---|
| OOD detector + tests | Done | `src/quality/ood.py`, additive flag only |
| Calibration/ECE script | Done | Ran for real — see external evaluation below |
| Latency benchmark | Done | Records numbers; needs HW annotation |
| Camera validation harness | Done | Needs labeled per-camera data |
| Retention purge + tests | Done | |
| Latency numbers reconciled in docs | **Now** | Measured-on-M3 vs field budget |
| Real calibration run | Done | ECE=0.064 on 2,810 labeled images (`results/labeled_evaluation.json`) |
| Real camera validation run | Blocked | Needs per-camera labeled data |

## Phase 3b — Input safety & external validation — **Done**
| Item | Status | Note |
|---|---|---|
| Domain gate (Model 0) | Done | `src/quality/fundus_gate.py`; non-retinal ⇒ `IMG_NOT_FUNDUS`, never a grade |
| Gate calibrated on real data | Done | 400-image calibration: FRR 42% → 6.9% on 2,810 images, adversarial corpus stays 14/14 rejected |
| Adversarial corpus + sweep test | Done | `test_samples/03_…` (14 fixtures) + `tests/red_team/test_corpus_sweep.py` (76 subtests), wired in CI |
| External accuracy evaluation | Done | `evaluate_labeled_dataset.py` + `docs/EVALUATION_RESULTS.md`: acc 71.5%, QWK 0.31, referable sens 0.21 |
| End-to-end demo rehearsal | Done | `demo_rehearsal.py` × 2 runs green, evidence in `results/demo_rehearsal/` |

## Phase 4 — Mobile app — **Next**
Flutter SDK (3.41.9) now runs locally: `flutter analyze` (2 pre-existing infos) and
`flutter test` are green; CI has a full Flutter job (analyze/test/web build +
Pages deploy, plus macOS/iOS/Linux build jobs). Audit findings fixed in code.
Still open: queue persistence across restart, real camera/connectivity plugins.

## Phase 5 — Docs & deck fidelity — **Ongoing**
Every figure must be reproducible from code. Current rule: measured-on-M3 numbers are
labeled as such; i3/4GB field figures stay as budgeted targets until measured on
that hardware. Deck regenerated from `_build_drishti_ppt.py` only.

## Phase 6 — Bug-hunt rounds — **Ongoing**
Recurring audits (src, api, demo, Flutter) with verify-fix-prove discipline.
Full gate every round: `pytest tests/` + `test_api_endpoints.py` +
`verify_complete_system.py` all green.

## Known limitations (honest, not silently dropped)
- Simulated backend exists when TF weights are absent; responses label it.
- External validation (2,810 labeled images, `docs/EVALUATION_RESULTS.md`):
  accuracy 71.5% but macro-F1 0.26 and **referable-DR sensitivity 0.21** —
  triage-assist with mandatory human review, never an autonomous screener.
- Model 1 pass rate was retuned from ~41% to **75.7%** on the full real
  screening set (blur threshold 35→15, calibrated on a 600-image
  metric+prediction join); every corpus failure fixture is still rejected.
- Referable-DR operating point calibrated and confirmed on a held-out split:
  sensitivity 0.25 → 0.62 at t=0.09 (spec 0.97 → 0.78) — still far from
  screening-grade 0.9; that requires model improvement, not thresholds.
- Domain gate false-reject rate is 6.9% on external data (safe direction:
  over-refuse rather than invent a grade).
- A/B + calibration metrics on synthetic cohorts are behavior metrics, not clinical claims.
- Single-worker SQLite; multi-worker needs Postgres/Redis.
- No patient-identity/ownership model (all keys see all records; reads audited).
- Dev keys are public strings; prod must set `DRISHTI_API_KEYS`.
