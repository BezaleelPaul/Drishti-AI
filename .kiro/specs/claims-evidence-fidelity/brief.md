# Brief: claims-evidence-fidelity

## Problem
The project's credibility and safety depend on every published number being traceable to a committed artifact. Three headline figures — QWK 0.8931 and referable sensitivity 99.70% — are presented as our results in `ROADMAP.md:45,71`, `presentation/TECHUTSAV_EXPO_DEFENSE_AND_PITCH.md:28,108-109`, `presentation/EXPO_POSTER.html:451-469` ("Surpasses the international clinical deployment threshold (0.80 QWK)… virtually zero referable diabetic cases missed") and `presentation/OFFLINE_DEMO_BACKUP.html:226-230`. They trace to a third-party HuggingFace model card (`adarshcod30/drdetect-dr-screening`) and a harness docstring (`kaggle/BENCHMARK_MODEL_COMPARISON_HARNESS.py:1002-1003`), with **no committed results artifact**. Every committed evaluation file reports the Keras backend at QWK 0.3082 / referable sensitivity 0.2127 (`results/labeled_evaluation.json`). Judges, reviewers and future maintainers reading these materials would be given a materially wrong picture of the shipped system's performance.

## Current State
Verified during discovery:
- **Unevidenced claims**: the two figures above appear in 5+ files with no backing artifact. `presentation/EXPO_POSTER.html` additionally asserts a clinical deployment threshold.
- **Contradicted claims** (live-verified): "76 subtests" (`README.md:159`, `docs/EVALUATION_RESULTS.md:113`) is actually 64; "2/2 runs green, 26 assertions" (`README.md:161`) is actually 1 run / 23 assertions (`results/demo_rehearsal/summary.json`); "run the full verification suite < 1 s" (`README.md:265`, `DEVELOPER_README.md:157`) measured 17.8 s; README latency figures (`README.md:42`) differ 10–100x from `results/benchmark.json` (quality gate 177.7 ms, full router 1014.2 ms); stale test counts at `docs/EVALUATION_RESULTS.md:142-143`.
- **Unverified claims**: "Validated on Remidio, Forus 3Nethra, Volk iNview" (`README.md:102`) with no `results/camera_validation.json`; "Fully validated on … macOS" (`README.md:293`) when CI matrix is ubuntu+windows only (`.github/workflows/ci.yml:15-16`); "HIPAA/ABDM FHIR R4-compliant" (`presentation/TECHUTSAV_EXPO_DEFENSE_AND_PITCH.md:58`); "confidence intervals are reported transparently" (`README.md:139`) with zero CI code in the repo.
- **Correctly evidenced and must be preserved**: accuracy 71.5% / QWK 0.31 / sensitivity 0.21 / ECE 0.064 (`README.md:152-156`), model 1 pass rate 75.7% (`README.md:157`), the explicit "we are NOT claiming medical device certification" guardrail (`README.md:136-137`), and the honest known-limitations block in `ROADMAP.md`.

## Desired Outcome
Every performance, accuracy, latency, platform and compliance figure published anywhere in the repository resolves to a committed file, or is removed/relabelled. No material claims a capability the shipped system does not have. `demo_rehearsal.py` stays green.

## Approach
Build a claims registry (a single machine-readable file, e.g. `docs/CLAIMS.md` plus a validation script) mapping each published claim to its evidence file, then sweep `README.md`, `DEVELOPER_README.md`, `TEAM_BRIEF.md`, `ROADMAP.md`, `docs/`, `presentation/` and `RELEASE_NOTES_*.md` against it. Replace the two unevidenced headline figures with the committed numbers; delete threshold/compliance language that has no artifact; correct the four contradicted counts and the latency section by labelling measured-on-M3 vs `results/benchmark.json` separately. Add a lightweight test that fails if a known-banned figure reappears.

## Scope
- **In**: a claims registry with evidence paths; removal/correction of unevidenced and contradicted figures across README, docs, ROADMAP and presentation; a regression test that greps for banned figures; completion of `test_samples/ATTRIBUTION.md` for `real_clinical_*` and `phone_random/*`; consistent latency labeling (measured vs budgeted).
- **Out**: re-running benchmarks or the benchmark harness; changing any model; rewriting the deck's design; clinical or regulatory work; touching `results/` outputs.

## Boundary Candidates
- Claim inventory and evidence mapping (what exists and what backs it)
- Material sweep and rewrite (README / docs / presentation / ROADMAP)
- Automated regression guard (banned-figure grep test)
- Attribution and provenance completion for committed sample images

## Out of Boundary
- Producing new measurements to justify a claim — if evidence is absent, the claim goes.
- Any statement about clinical efficacy, regulatory status or screening-grade performance.
- Modifying `results/*.json` artifacts or the evaluation scripts that produced them.

## Upstream / Downstream
- **Upstream**: `results/labeled_evaluation.json`, `results/demo_rehearsal/summary.json`, `results/benchmark.json`, `.github/workflows/ci.yml` (what actually runs), `docs/EVALUATION_RESULTS.md`.
- **Downstream**: `demo_rehearsal.py` and the expo deck regeneration path; every future spec that might otherwise reintroduce a figure.

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `test-ci-coverage-gate` (shares the CI test harness for the regression guard); `explainability-truthfulness` (corrects Grad-CAM wording such as `presentation/DEMO_VIDEO_SCRIPT.md:42` and `README.md:122`).

## Constraints
- Do not delete honest, evidenced disclosures (the low sensitivity figure and the "not a medical device" guardrail must remain).
- Corrections must not break `demo_rehearsal.py` or the PPT builder.
- Every edit must be defensible from a file in the repository — no new numbers introduced.
