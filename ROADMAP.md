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
| Calibration/ECE script | Done | Needs labeled grade_0..4 data to run for real |
| Latency benchmark | Done | Records numbers; needs HW annotation |
| Camera validation harness | Done | Needs labeled per-camera data |
| Retention purge + tests | Done | |
| Latency numbers reconciled in docs | **Now** | Measured-on-M3 vs field budget |
| Real calibration run | Blocked | Needs labeled fundus dataset |
| Real camera validation run | Blocked | Needs per-camera labeled data |

## Phase 4 — Mobile app — **Next / Blocked**
All 36+ audit findings fixed in code, but: no Flutter SDK on any dev machine, so
`flutter analyze` / widget tests have never run. CI has a Flutter job for this.
Queue persistence (survive restart) and real camera/connectivity plugins still open.

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
- A/B + calibration metrics on synthetic cohorts are behavior metrics, not clinical claims.
- Single-worker SQLite; multi-worker needs Postgres/Redis.
- No patient-identity/ownership model (all keys see all records; reads audited).
- Dev keys are public strings; prod must set `DRISHTI_API_KEYS`.
