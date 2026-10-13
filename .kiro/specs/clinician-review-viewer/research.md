# Research Log — clinician-review-viewer

Discovery type: **light** (extension of an existing review flow + API). No new external dependencies; no web research needed. All findings verified against source during the design phase.

## Summary

Goal: let a tele-ophthalmologist open a pending review case, see the real fundus image zoomed, and see honest anatomical + lesion-candidate markers at their true positions — with an honest unavailable state and zero invented markers.

Two facts reshaped scope from "expose existing data" to "compute on demand + serve coordinates":

1. **Segmentation is gated to the BORDERLINE quality path** (`src/pipeline/router.py:163-167`). Cases that pass quality (GOOD) but still land in the review queue have no segmenter output at all. The marker endpoint must therefore run `RetinalStructureSegmenter` on demand for any review case, not just read precomputed values.
2. **The review queue is text-only and holds no image.** `doctor_review_screen.dart` receives `original_image_url` from `GET /review/pending` (`api/routes/review.py:91`) but discards it. The viewer must fetch the image itself from the existing path-safe route.

## Research Log

### Integration points (verified)

- **Segmenter**: `RetinalStructureSegmenter.segment_structures(img_rgb: np.ndarray) -> RetinalStructuresResult` (`src/segmentation/structure_segmenter.py:61`). Result carries `optic_disc_center: (x, y)`, `optic_disc_radius: int`, `fovea_center: (x, y)`, `microaneurysm_candidates: list[(x, y, r)]` (lines 23-27). Reusable singleton already lives on the router: `self.structure_segmenter` (`router.py:50`), and `ai_bridge` reaches it as `self.router.structure_segmenter` (`ai_bridge.py:322`). The marker endpoint reuses that same instance — no second segmenter, no new ML dependency.
- **Image decode**: the same capped lazy-decode path the router uses — `_open_image_capped` + `np.array(pil_img)` (`ai_bridge.py:227-228, 322`). Marker coordinate space is this decoded image's `(H, W)`.
- **Review → image path**: `doctor_reviews JOIN screenings` already yields `s.original_image_path` (`review.py:61`), stored as `results/api_screenings/{screening_id}/{screening_id}_orig.jpg` (`ai_bridge.py:229-231`).
- **Image serving**: existing `GET /results/{screening_id}/{filename}` (`api/routes/results.py:26-51`), auth-gated (`require_auth`), path-traversal-safe (screening-id regex + filename allowlist + realpath containment). The viewer reuses this to display the image; the marker endpoint only needs the decoded pixels, not a second file-serving route.
- **Doctor auth**: review routes already use `require_doctor` (`review.py:41`). The new marker route reuses it. Flutter attaches `X-API-Key` on every call (`api_service.dart:100`).

### Key decisions from discovery

- **Reuse, don't add**: no new route for the image, no new dependency, no second segmenter. Marker endpoint = one new GET route + one schema, reusing the router's segmenter and the existing image-serving route.
- **On-demand over precompute**: running segmentation inside the marker GET is simple and correct. Concern: the segmenter loads an optional DL toolbox model on init (`structure_segmenter.py:51-59`). Reusing the already-warm `router.structure_segmenter` avoids re-loading that model per request.
- **Fail closed, advisory-only**: every failure (no image, decode error, segment error, timeout) returns HTTP 200 with `available: false` + reason — never a partial/guessed coordinate, never a 5xx that would look like a system fault to the doctor. This mirrors the existing "biomarkers are advisory, never block screening" posture (`ai_bridge.py:328`).

## Synthesis

- **Generalization found**: the "advisory, never block, fail to None/absent" pattern already used for biomarkers (`ai_bridge.py:311-328`) is the correct template for markers. Markers follow it exactly — but expose coordinates instead of collapsing them to counts.
- **Build-vs-adopt**: build the viewer from Flutter primitives (`InteractiveViewer`, `Stack`, `CustomPainter`) rather than adopting a library. `InteractiveViewer` is already the app's zoom idiom (`ScannerView`, `minScale: 1.0`, `maxScale: 3.5`). No new dependency (honours the spec constraint).
- **Simplification**: the wipe is two identically-positioned image layers in a `Stack`, the top one wrapped in `ClipRect` sized by the wipe fraction, with the marker `CustomPainter` on top. Plain and marked layers share one transform, so zoom/pan stay locked by construction — no separate sync logic to get wrong.
- **Out of scope confirmed**: vessel/exudate masks (payload lightness), Grad-CAM (owned by `explainability-truthfulness`), the three operator result screens (owned by `screening-ux-consolidation`).

## Risks

- **Coordinate-space mismatch** (the highest-risk item): markers drawn against the displayed image size instead of the decoded source `(H, W)` would point at the wrong retina — plausible-looking and clinically wrong. Mitigation: the payload carries source `width`/`height`; the painter maps `source → fitted/zoomed` through one shared transform and is tested against known positions across zoom levels.
- **Segment latency on the review path**: on-demand segmentation runs on a doctor tap. Mitigation: the decision/sign-off path never waits on markers (Requirement 6.3); a slow marker load degrades to the unavailable state, never a blocked decision.
- **Empty-but-real**: an empty `ma_candidates` list must be distinguished from "unavailable." The payload has both `available: true` + empty list (healthy: no candidates) and `available: false` (could not compute).
