# Brief: clinician-review-viewer

## Problem
A tele-ophthalmologist reviewing a flagged case sees only a text queue row (patient name, grade, confidence, clinical flag) and a dead "View Heatmap" button that emits a SnackBar stub (`doctor_review_screen.dart:305-315`). They cannot see the fundus image, and nothing points at the specific retinal regions the pipeline flagged. The decision to confirm or override a DR grade is made blind to the very anatomy that drove it.

The computed spatial data that would fix this already exists but is discarded. `RetinalStructuresResult` (`src/segmentation/structure_segmenter.py:21-33`) carries `optic_disc_center`, `optic_disc_radius`, `fovea_center`, and `microaneurysm_candidates: list[(x, y, radius)]`. The router computes it only on the BORDERLINE quality path (`src/pipeline/router.py:163-167`) and collapses it to four scalar counts before the API ever sees it (`api/services/ai_bridge.py:297-365`). For CLEAR/quality-passed cases that still land in the review queue, segmentation is never run at all — so the coordinates a doctor needs are not merely hidden, they are absent.

This is a clinician-facing tool. It must not over-claim: these markers are classical-CV candidate detections for human review, NOT model attention and NOT a diagnosis.

## Current State
- **Coordinates exist and are real**: `structure_segmenter.py` computes OD/fovea centers + radius and MA candidate `(x, y, r)` via sub-pixel top-hat morphology. It already frames every output as a "candidate" built for "<30s ophthalmologist validation."
- **Segmentation is gated to BORDERLINE**: `router.py:163-167` runs it only when `quality_res.grade == Quality_BORDERLINE`. Cases that pass quality and still require review have no segmenter output.
- **API collapses spatial data to scalars**: `ai_bridge.py:311-327` reads `seg.optic_disc_center`, `seg.fovea_center`, `seg.microaneurysm_candidates` but only emits `microaneurysm_count`, `min_fovea_distance_px`, etc. No coordinates leave the backend.
- **Review queue is text-only**: `GET /review/pending` (`api/routes/review.py:37-103`) already joins `s.original_image_path` and returns `original_image_url`, but `doctor_review_screen.dart` discards it — it renders name/grade/confidence only and never loads an image.
- **Image serving exists, path-safe**: `GET /results/{screening_id}/{filename}` (`api/routes/results.py:26-48`) validates the screening-id regex and realpath-confines to the results dir. A fundus image can be served without a new mechanism.
- **Reusable viewer plumbing**: `ScannerView` (`lib/widgets/scanner/scanner_view.dart`) exposes an `overlay` slot (line 23) and an `isInteractive` → `InteractiveViewer(minScale: 1.0, maxScale: 3.5)` (lines 153-168). No `InteractiveViewer` exists anywhere else in app code.
- **Adjacent honesty spec**: `explainability-truthfulness` owns Grad-CAM / model-explanation honesty and forbids presenting any map as model attention unless the same model produced it. It does NOT own anatomical/lesion candidate markers, which are classical CV.

## Desired Outcome
A doctor opens a pending review case and sees the fundus image zoomable to 3.5x, with honest markers drawn on it: the optic disc as a circle, the fovea as a crosshair, and each microaneurysm candidate as a small ring. A drag-to-wipe slider reveals the marked-up view over the plain image, both layers locked to the same zoom and pan so the doctor can confirm a marker's true position. Markers are labelled as algorithmic candidates for clinician review — never as model attention, never as a confirmed diagnosis.

When markers cannot be produced (ungradable, segmenter failure, unavailable offline), the viewer still loads the image and states plainly that markers are unavailable. It never invents, approximates, or decoratively fakes a marker.

## Approach
Three coordinated moves.

1. **Expose real coordinates through a dedicated endpoint.** Add `GET /review/{review_id}/markers` returning the fundus dimensions plus the marker set: `optic_disc {x, y, r}`, `fovea {x, y}`, `ma_candidates [{x, y, r}]`, each carrying `source: "classical_cv_segmentation"` provenance. Load the image from the review→screening→`original_image_path` chain (already joined in `review.py`), run `structure_segmenter.segment_structures()` **on demand** so CLEAR-path cases get markers too, and return `markers: null` with an honest reason on any failure — never a fabricated point. Markers are the only payload; vessel/exudate masks are deliberately out of scope to keep the response light.

2. **Build the zoom + drag-to-reveal viewer.** A `LesionMarkerPainter` (CustomPainter) draws markers in image-space, scale-aware so ring radii track zoom. Wrap the fundus image in a pinch-zoom `InteractiveViewer` (maxScale 3.5, matching `ScannerView`). A horizontal wipe slider cross-fades a plain image layer and a marked layer at identical zoom/pan. The painter refuses to render markers whose coordinates fall outside the image bounds.

3. **Integrate into the clinician review screen only.** Replace the dead "View Heatmap" stub in `doctor_review_screen.dart:305-315` with a real "View Markers" action that opens the viewer for that case. Do not touch the operator-facing `results_screen.dart`, `screening_result_screen.dart`, or `flow_result_screen.dart`.

## Scope
- **In**: on-demand segmentation for review cases; `GET /review/{review_id}/markers` endpoint + schema; honest provenance labelling; `RetinalMarkers` Flutter model; `LesionMarkerPainter`; pinch-zoom `InteractiveViewer`; drag-to-reveal wipe slider; wiring into `doctor_review_screen.dart` only; honest unavailable/empty states; unit tests for marker parsing and painter bounds; pytest + flutter test green.
- **Out**: vessel/exudate mask overlays (deferred — keep payload light); Grad-CAM or any model-attention heatmap (owned by `explainability-truthfulness`); the on-device explanation path; clinical interpretation of markers; touching the three operator result screens; improving segmentation accuracy; LIME/SHAP; new ML dependencies.

## Boundary Candidates
- Marker provenance (classical CV vs model attention) — must never blur.
- Coordinate space mapping (segmenter px vs displayed image size) — the source of silent misalignment.
- Honest empty/unavailable states vs decorative filler.
- On-demand segmentation cost on the review endpoint (a slow path must not block sign-off).

## Out of Boundary
- `explainability-truthfulness`: owns Grad-CAM honesty, the decorative-gradient removal, and the rule that no map may be called model attention unless the same model produced it. This viewer must comply with that framing but does not implement it.
- `on-device-inference-integrity`: on-device grading correctness; markers are server-computed and simply labelled unavailable when offline.
- `screening-ux-consolidation`: owns the operator result screens being edited there — this spec must not edit them.
- `claims-evidence-fidelity`: owns doc/README wording; any README note about markers is deferred to it.

## Existing Spec Touchpoints
- **Adjacent**: `explainability-truthfulness` (honesty rules this must obey); `screening-ux-consolidation` (owns the screens this must NOT edit); `on-device-inference-integrity` (offline labelling).
- **Extends**: none.

## Upstream / Downstream
- **Upstream**: `src/segmentation/structure_segmenter.py` (coordinate source), `src/pipeline/router.py` (existing borderline-only invocation), `api/services/ai_bridge.py` (where scalars currently discard coordinates), `api/routes/review.py` + `api/schemas.py` (queue join already carries image path).
- **Downstream**: none blocking. Optional README/architecture note on markers is handed to `claims-evidence-fidelity`.

## Constraints
- `pytest tests` and `flutter test` stay green; existing red-team and Grad-CAM integration tests (`tests/integration/test_ml_quality_and_gradcam.py`) keep passing.
- No fabricated markers under any circumstance — missing data renders as an honest unavailable/empty state, never a guessed point.
- Markers labelled "algorithmic candidates for clinician review," never "AI detected" or "what the model saw."
- Existing honest disclaimers are preserved, not removed.
- No new ML or heavy dependencies; reuse `ScannerView`/`InteractiveViewer` and standard Flutter painting.
- On-demand segmentation must be non-blocking for the sign-off path and must fail closed.
