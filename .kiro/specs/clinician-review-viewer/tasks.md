# Implementation Plan — clinician-review-viewer

Order implies dependency: task N depends on all prior tasks unless marked `(P)`. Boundary names come from `design.md`.

- [ ] 1. Foundation: marker payload contract on both sides
- [x] 1.1 Add the marker response schemas to the backend schema module
  - Define the marker payload contract: availability flag + reason, provenance string, source dimensions, optic-disc, fovea, and a list of microaneurysm candidate points.
  - The contract distinguishes "unavailable" (no image / failure) from "available but empty candidates" so a healthy retina is never shown as unavailable.
  - Done when the schema module imports cleanly and a payload can be constructed for both the available and the unavailable case.
  - _Boundary: ReviewMarkersResponse_
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 1.2 Add the typed Flutter marker model with JSON parsing
  - Mirror the payload contract in a typed Dart model with a `fromJson` factory.
  - Model carries source width/height for the display mapping and represents the unavailable vs empty distinction explicitly.
  - Done when the model parses a sample available payload and an unavailable payload without loss of the availability distinction.
  - _Boundary: RetinalMarkers_
  - _Requirements: 2.1, 2.4, 3.1_

- [ ] 2. Backend: on-demand marker computation and route
- [x] 2.1 (P) Build the marker service that decodes the image and runs the segmenter
  - Load the review's stored fundus image from its screening record and decode it with the same capped decode the pipeline uses.
  - Run the existing retinal-structure segmenter and map its output to the payload contract, keeping coordinates in the decoded source pixel space.
  - Fail closed to an unavailable payload with a reason on missing image, decode failure, segmenter exception, or timeout — never fabricate or partially populate markers.
  - Done when, for a stored review image, the service returns a payload with real optic-disc/fovea/candidate coordinates plus source dimensions, and returns unavailable for a missing image.
  - _Boundary: marker_service_
  - _Depends: 1.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4_

- [x] 2.2 (P) Add the doctor-authenticated marker route for a review case
  - Expose a read-only route keyed by review case that reuses the existing doctor authorization and returns the marker payload.
  - Unknown review returns not-found; missing or insufficient auth returns the existing auth failure. A segmentation failure is a successful response carrying an unavailable payload, not a server error.
  - Done when an authorised doctor key retrieves markers for an existing case, an unknown case returns 404, and an unauthenticated request is rejected.
  - _Boundary: MarkerRoute_
  - _Depends: 1.1_
  - _Requirements: 1.1, 6.3_

- [ ] 3. Flutter: zoomable marker viewer with drag-to-reveal wipe
- [x] 3.1 (P) Build the lesion marker painter that draws markers in image space
  - Draw the optic disc as a circle, the fovea as a crosshair, and each microaneurysm candidate as a ring, positioned by mapping source-image coordinates through the supplied display transform.
  - Scale marker sizes with zoom, and skip any marker whose mapped position falls outside the image bounds.
  - Done when a marker placed at a known source coordinate renders at the expected displayed position and stays aligned as the transform scale changes.
  - _Boundary: LesionMarkerPainter_
  - _Depends: 1.2_
  - _Requirements: 3.1, 3.2, 3.4_

- [x] 3.2 (P) Build the clinician marker viewer with zoom, wipe, and honest states
  - Display the fundus image under a pinch-zoom viewer supporting up to at least 3.5x, with markers drawn by the painter on the marked layer.
  - Provide a drag-controlled wipe that reveals the marked view over the plain view, with both layers sharing one transform so zoom and pan stay locked under the wipe.
  - Render markers and the image independently: a marker failure still shows the image with an honest unavailable state; markers unavailable means no wipe and no decorative overlay; empty candidates shows anatomical landmarks only with a plain "no candidates found" note.
  - Done when, with markers available, zooming keeps markers on their anatomy and the wipe reveals markers aligned to the plain view; with markers unavailable, the image renders with a plain unavailable message and no overlay.
  - _Boundary: ClinicianMarkerViewer_
  - _Depends: 1.2, 3.1_
  - _Requirements: 3.1, 3.2, 3.3, 3.5, 4.1, 4.2, 4.3, 5.1, 5.2, 5.3_

- [x] 3.3 Wire the viewer into the review case, replacing the dead heatmap stub
  - Replace the review case's dead "View Heatmap" affordance with a "View Markers" action that opens the viewer for that case, loading markers and the image for the selected case.
  - Marker loading must never block or delay the doctor's ability to return to the queue or submit a sign-off decision.
  - Done when opening a case's markers shows the viewer for that case, and a failed marker load leaves the queue and sign-off action fully usable.
  - _Boundary: DoctorReviewScreen_
  - _Depends: 2.2, 3.2_
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 4. Validation: honesty, mapping, and regression coverage
- [x] 4.1 (P) Test marker service honesty and fail-closed behaviour
  - Verify a stored review image yields real coordinates plus dimensions, and that a missing image, decode failure, and segmenter exception each yield an unavailable payload with a reason and no fabricated marker.
  - Done when the test suite covers the available case and each failure mode and passes.
  - _Boundary: marker_service_
  - _Depends: 2.1_
  - _Requirements: 1.1, 1.3, 1.4, 7.1_

- [x] 4.2 (P) Test marker route access control and on-demand computation for quality-passed cases
  - Verify an authorised doctor key retrieves markers, an unknown review returns not-found, and an unauthenticated request is rejected.
  - Verify a quality-passed (non-borderline) review case still returns markers, proving markers are computed on demand rather than only on the borderline path.
  - Done when these route tests pass.
  - _Boundary: MarkerRoute_
  - _Depends: 2.2_
  - _Requirements: 1.2, 6.3, 7.1_

- [x] 4.3 Test coordinate mapping across zoom and honest viewer states
  - Verify a marker at a known source coordinate maps to the expected displayed position across multiple zoom levels, and that an unavailable payload renders no markers and no decorative overlay.
  - Done when the painter and viewer tests pass and confirm markers stay aligned under zoom.
  - _Boundary: LesionMarkerPainter, ClinicianMarkerViewer_
  - _Depends: 3.1, 3.2_
  - _Requirements: 3.1, 3.2, 5.1, 5.3, 7.1, 7.2_

- [x] 4.4 Run the full regression gate
  - Run the backend test suite, the Flutter test suite, and static analysis; confirm no pre-existing test regressed and no new analysis issues were introduced.
  - Done when the backend suite, the Flutter suite, and analysis all pass with no new issues.
  - _Depends: 2.2, 3.3, 4.1, 4.2, 4.3_
  - _Requirements: 7.3_

## Implementation Notes
- Python interpreter for validation is `.\venv\Scripts\python.exe` (has pytest). Plain `python` is a different interpreter WITHOUT pytest — do not use it.
- Task 1.1 review caught a real contract-level honesty hole: typing `source: str` with only a default let a caller set `source="model attention"`, fabricating provenance. Fixed with `Literal["classical_cv_segmentation"]`. Lesson for later tasks: honesty invariants must be STRUCTURALLY enforced (types/Literals), and tests must probe the override path, not just the default.
- The git index already held unrelated pre-existing staged `demo/` files at feature start; they rode into commit `4d806f2`. Fixed for task 1.2: ran `git reset -- demo` to unstage, then staged explicit paths only (commit `450a7c2` = exactly 3 task files). Continue staging explicit paths only.
- Task 2.1 review notes (recorded per reviewer request): marker_service constructs its OWN locked segmenter singleton instead of literally reusing `router.structure_segmenter` — deliberate deviation from design letter, honoring design substance: reuse via `AIBridge.get_instance()` would pull classifier/GradCAM/risk-model init into the advisory marker path (against Req 6.3). One-time ~20s cold-init per process (DL toolbox import attempt then geometric fallback), 0ms warm. Timeout hardening deferred to route level; service catches all exceptions but cannot preempt a hung segmentation. Service passes segmenter output through (incl. OOB) — painter owns OOB drop (Req 3.4).
- Task 3.1 review notes: painter verified correct-by-construction for contain-fit (viewer must hand the REAL fitted imageRect — done in 3.2). Inclusive-edge OOB semantics deliberate and tested. `../scanner/scanner_theme.dart` import for color tokens (harmless). `strokeScale`: painter INSIDE zoom transform → 1.0; OUTSIDE → pass zoom. Painter clips to imageRect; fovea crosshair fixed 8px display (deliberate, payload has no fovea radius).
- Task 3.2 review notes: single shared InteractiveViewer over both layers verified (no drift possible); contain-fit math hand-verified (400×400 viewport, 1000×500 src → Rect(0,100,400,200)); painter inside transform with strokeScale 1.0; wipe defaults 1.0 (fully marked at rest); markers never render before image pixels; null fetcher → honest text. Viewer takes injected fetchers — task 3.3 wires production closures. Full suite 196 passed / analyze clean.
- Final validation (4.4): pytest 158 passed + 127 subtests; flutter test 214 passed; flutter analyze 0 issues; TODO/secret greps clean across all 8 feature files; Python-schema↔Dart-model contract parity exact (9/9 field keys); smoke boot PASS (app assembles, marker route registered in openapi, auth gate intact). Zero regressions vs feature baselines (125 pytest / 162 flutter at start).
