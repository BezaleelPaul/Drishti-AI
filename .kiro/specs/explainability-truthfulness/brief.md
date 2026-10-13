# Brief: explainability-truthfulness

## Problem
The explanation shown to an operator does not come from the model that produced the grade, and in three screens it is not an explanation at all. The shipped and default backend is ONNX (`src/classification/classifier.py:89-98`), but `GradCAMExplainer` only handles Keras and PyTorch backends (`src/classification/gradcam.py:87,97`) — with no ONNX branch, every heatmap silently becomes `_compute_synthetic_attention_map`, a green-channel morphological saliency **not derived from the model** (`gradcam.py:109-116,317-353`), reported as `multiscale_vascular_saliency (fallback)` (`gradcam.py:47`). The project's own truthfulness gate confirms the problem: `results/xai_insertion_deletion.json` shows `gates_passed: 0`, `all_passed: false` — 4 of 4 images fail — yet heatmaps are still served (`api/services/ai_bridge.py:259-268`).

On the Flutter side, when the real overlay URL is null/empty or the network load fails, `screening_result_screen.dart:438-472` renders a decorative red/amber `RadialGradient` still labelled "Grad-CAM++ Overlay (N/A)"; `results_screen.dart:410-477` renders a pure radial gradient whose color depends on `isReferable`; `flow_result_screen.dart:320-350` shows the same decorative gradient as "AI Attention Map". `doctor_review_screen.dart:304-321` offers a "View Heatmap" button that shows only a SnackBar. Meanwhile the API's static disclaimer promises "highest gradient activation" regardless of the fallback, because the dynamic `FALLBACK_NOTE` is never propagated (`ai_bridge.py:331-368` omits it).

## Current State
- **Real Grad-CAM++ exists** and works on the backends it supports: Keras `GradientTape` over the last 4D conv layer (`gradcam.py:133-232`), PyTorch hooks over the last `Conv2d` (`gradcam.py:234-315`), target class = predicted grade (`src/pipeline/router.py:306-311`).
- **Consistent for Keras only**: same model and same 224px raw-RGB tensor as `_predict_keras` (`classifier.py:286-289` vs `gradcam.py:151-156`) — verified consistent for that backend.
- **No ONNX branch** → default deployment path yields a non-model map.
- **Gate failed but output still served**; `validate_xai.py:151` loads `final_model.keras` directly, so the validator never exercises the ONNX live path either.
- **No LIME/SHAP/attention code** anywhere (absent, not missing work).
- **Over-claiming copy**: "Highlighted regions show areas that influenced the AI prediction" (`l10n/app_strings.dart:103-104`), "why_result" asserting detected "microaneurysms, haemorrhages, and exudates" (`app_strings.dart:121-122`), and `presentation/DEMO_VIDEO_SCRIPT.md:42` "Grad-CAM visualizes the exact microaneurysms and hemorrhages" — which contradicts the project's own disclaimer at `src/classification/gradcam.py:36-38` and `src/pipeline/schema.py:145-146`.
- **Honest counterweights that must survive**: disclaimers in `gradcam.py:41-45`, `schema.py:143-147`, `screening_result_screen.dart:502`, and the "Illustrative overlay*" badge (`results_screen.dart:467,486`).

## Desired Outcome
Any heatmap presented as a model explanation is computed by the same model instance, on the same preprocessed tensor, that produced the displayed grade — or no heatmap is presented at all. No decorative gradient is ever rendered where a Grad-CAM would be expected. The user-visible explanation states plainly when it is a fallback or is unavailable. Explanation wording never asserts lesion-level detection.

## Approach
Three coordinated moves. (1) **Close the provenance gap**: give `GradCAMExplainer` an ONNX branch (gradients through the ONNX session for the predicted ordinal/threshold output), or, if that proves infeasible during implementation, explicitly bind explainability to a backend that supports it and withhold explanations whenever the active backend cannot produce a model-derived map. (2) **Enforce the gate**: treat `results/xai_insertion_deletion.json`'s `all_passed` as a release gate — on failure, the API returns "explanation unavailable" instead of a map, and `validate_xai.py` is updated to exercise the *live* backend rather than loading Keras directly. (3) **Remove decorative overlays**: replace the three radial-gradient stand-ins and the SnackBar-only heatmap with a single honest unavailable/not-applicable state, propagate the dynamic fallback note through `ai_bridge.py` into `api/schemas.py`, and rewrite the over-claiming strings.

## Scope
- **In**: ONNX Grad-CAM support or explicit backend-scoped withholding; gate enforcement so a failing truthfulness gate suppresses rather than serves; `validate_xai.py` testing the live backend; removal of all decorative gradient overlays and the SnackBar-only heatmap; propagation of the fallback note through the API schema; correction of over-claiming UI and presentation strings.
- **Out**: adding LIME/SHAP/attention methods; improving CAM quality or resolution; changing model architecture or gradients for accuracy; the on-device explanation path beyond labeling it unavailable; clinical interpretation of heatmaps.

## Boundary Candidates
- Provenance (which model/tensor produced this map)
- Gate policy (what happens when truthfulness fails)
- UI honesty (decorative vs real vs unavailable states)
- Explanation copy and its claims boundary

## Out of Boundary
- On-device inference correctness (`on-device-inference-integrity`).
- Grad-CAM's role in the abstention path — note that Grad-CAM failure already mandates clinician review (`router.py:312-320,338-341`); do not change that policy here without review.
- Any claim that a heatmap proves lesion presence.

## Upstream / Downstream
- **Upstream**: `src/classification/gradcam.py`, `src/classification/classifier.py` backend selection, `results/xai_insertion_deletion.json`, `api/services/ai_bridge.py`, the three Flutter result screens.
- **Downstream**: `claims-evidence-fidelity` (corrects `README.md:122`, `docs/ARCHITECTURE.md:69,84`, `DEMO_VIDEO_SCRIPT.md:42`, `docs/EVALUATION_RESULTS.md:250-252` which claims heatmaps are "NOT presented to operators" while the API serves them); `test-ci-coverage-gate` (gate becomes a CI assertion).

## Existing Spec Touchpoints
- **Extends**: none (first spec set).
- **Adjacent**: `on-device-inference-integrity` (identifies which model graded, prerequisite for provenance); `claims-evidence-fidelity` (owns the doc wording sweep); `screening-ux-consolidation` (owns the screens being edited — coordinate to avoid duplicate edits to `flow_result_screen.dart` and `results_screen.dart`).

## Constraints
- `pytest tests` and `flutter test` must stay green; the existing red-team and Grad-CAM integration tests (`tests/integration/test_ml_quality_and_gradcam.py`) must keep passing.
- Prefer withholding an explanation over presenting a weaker substitute — never invent a map.
- Do not remove the existing honest disclaimers; the fix is to remove the dishonest ones.
- No new dependencies.
