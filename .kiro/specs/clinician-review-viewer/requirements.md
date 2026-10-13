# Requirements Document

## Introduction

A tele-ophthalmologist reviewing a flagged Drishti-AI case currently decides whether to confirm or override a DR grade while blind to the anatomy that produced it. The review queue (`doctor_review_screen.dart`) shows a text row — patient name, grade, confidence, clinical flag — and a "View Heatmap" control that only emits a SnackBar stub (`doctor_review_screen.dart:305-315`). No fundus image is shown, and nothing points at the retinal regions the pipeline flagged.

The spatial data that would fix this already exists but is discarded. `RetinalStructuresResult` (`src/segmentation/structure_segmenter.py:21-33`) carries the optic-disc centre and radius, the fovea centre, and a list of microaneurysm candidates as `(x, y, radius)` points. The router computes these only on the BORDERLINE quality path (`src/pipeline/router.py:163-167`) and the API collapses them to scalar counts before the client ever sees them (`api/services/ai_bridge.py:311-327`). For cases that pass quality yet still require review, segmentation is never run at all — so the coordinates a doctor needs are not merely hidden, they are absent.

This specification makes one guarantee testable: a clinician can open a pending review case, see the real fundus image, zoom it, and see honest anatomical and lesion-candidate markers drawn at their true positions — or see a plain statement that markers are unavailable. Markers are classical-computer-vision candidates for human review, never model attention and never a diagnosis, and no marker is ever invented to fill empty space.

## Boundary Context (Optional)

- **In scope**: on-demand anatomical/lesion segmentation for a review case; serving the optic-disc, fovea, and microaneurysm-candidate coordinates with honest provenance and dimensions; a clinician-facing zoomable fundus viewer with a drag-to-reveal wipe between the plain and marked image; correct mapping of marker coordinates to displayed image space; honest unavailable and empty-marker states; wiring the viewer into the tele-ophthalmologist review screen only; tests proving coordinate mapping, honesty, and fail-closed behaviour.
- **Out of scope**: vessel or exudate mask overlays; Grad-CAM or any model-attention heatmap (owned by `explainability-truthfulness`); the on-device explanation path; clinical interpretation of markers; improving segmentation accuracy or thresholds; editing the operator-facing result screens (`results_screen.dart`, `screening_result_screen.dart`, `flow_result_screen.dart`, owned by `screening-ux-consolidation`); model retraining or new ML dependencies.
- **Adjacent expectations**: this specification expects `explainability-truthfulness` to remain the sole owner of Grad-CAM/model-attention honesty and to keep any map labelled as model attention withheld unless the same model produced it; this viewer's markers are classical-CV candidates and must never be labelled as model attention. It expects the existing doctor authentication on review endpoints and the path-safe result-image serving to remain in place. It expects sign-off/decision submission to remain independent of marker generation — a marker failure must never block a doctor from deciding. It expects the operator result screens owned by `screening-ux-consolidation` to remain untouched.

## Project Description (Input)

### (a) Who has the problem

Tele-ophthalmologists and reviewing clinicians who must confirm or override an AI-flagged DR referral, and the patients whose referral accuracy depends on that review being grounded in the actual image rather than a text summary.

### (b) Current situation

Verified during discovery against source:

- The review queue is text-only. `GET /review/pending` (`api/routes/review.py:37-103`) already joins `s.original_image_path` and returns an image URL, but `doctor_review_screen.dart` discards it and renders only name, grade, confidence, and flag.
- The only "view" affordance is a dead stub: `doctor_review_screen.dart:305-315` shows a SnackBar reading "Viewing High-Resolution Grad-CAM Heatmap..." and renders nothing.
- Real marker data exists but is discarded: `structure_segmenter.py` computes `optic_disc_center`, `optic_disc_radius`, `fovea_center`, and `microaneurysm_candidates: list[(x, y, radius)]`; the API keeps only `microaneurysm_count` and `min_fovea_distance_px` (`ai_bridge.py:311-327`).
- Segmentation is gated to BORDERLINE (`router.py:163-167`); quality-passed cases that still enter review have no segmenter output at all.
- A path-safe image-serving route already exists: `GET /results/{screening_id}/{filename}` (`api/routes/results.py:26-48`) validates the screening-id pattern and confines the path.
- Reusable viewer plumbing exists: `ScannerView` exposes an `overlay` slot and an `InteractiveViewer` at `minScale: 1.0`, `maxScale: 3.5` (`scanner_view.dart:23,153-168`); no other `InteractiveViewer` exists in app code.
- The segmenter itself frames every output as a candidate "for <30s specialist review" — the honesty framing this spec must preserve.

### (c) What should change

**Objective:** Let a clinician open a pending review case, see the real fundus image zoomable, and see honest anatomical and lesion-candidate markers at their true positions — with an honest unavailable state and no invented markers.

### In scope

1. Run anatomical/lesion segmentation on demand for a review case, including quality-passed cases, so markers exist whenever they can be computed.
2. Serve the optic-disc, fovea, and microaneurysm-candidate coordinates together with image dimensions and honest provenance.
3. Provide a clinician viewer that zooms the fundus image and draws markers at their true positions.
4. Provide a drag-to-reveal wipe between the plain and marked image, with both layers locked to the same zoom and pan.
5. Render an honest unavailable/empty state when markers cannot be produced; never invent a marker.
6. Wire the viewer into the tele-ophthalmologist review screen only.
7. Test coordinate mapping, honesty labelling, and fail-closed behaviour.

### Out of scope

- Vessel/exudate mask overlays (deferred to keep the payload light).
- Grad-CAM or model-attention heatmaps.
- Editing the operator result screens.
- Improving segmentation accuracy.

### Important constraints

- Markers must never be fabricated; missing data renders as an honest unavailable/empty state.
- Marker generation must be non-blocking for the review decision path and must fail closed.
- Existing `pytest tests` and `flutter test` suites must remain green.

## Requirements

### Requirement 1: On-demand marker computation for a review case

**Objective:** As a reviewing clinician, I want markers computed for the case I opened — including quality-passed cases — so that I can see the anatomy behind a referral that is not blocked by a BORDERLINE-only segmentation path.

#### Acceptance Criteria
1. When a clinician requests markers for a pending review case, the system shall compute anatomical and lesion-candidate segmentation for that case's fundus image if it has not already been computed.
2. Where the case's quality grade is not BORDERLINE, the system shall still compute markers on request rather than returning an absent result solely because the borderline path was not taken.
3. If the case has no retrievable fundus image, the system shall return an unavailable result with a reason and shall not fabricate marker data.
4. If segmentation raises an error or times out, the system shall fail closed and return an unavailable result rather than partial or guessed coordinates.

### Requirement 2: Honest marker payload with provenance and dimensions

**Objective:** As a reviewing clinician, I want each marker delivered with its true pixel position, the image dimensions, and an honest statement of its source, so that I can trust what the markers mean and where they point.

#### Acceptance Criteria
1. When markers are available, the system shall return the image width and height together with the optic-disc centre and radius, the fovea centre, and each microaneurysm candidate's centre and radius, all expressed in the source image's pixel coordinate space.
2. The system shall label the marker source as classical computer-vision segmentation, and shall not label or present these markers as model attention, Grad-CAM, or a diagnosis.
3. Where markers are available but a microaneurysm candidate list is empty, the system shall return an explicitly empty list rather than omitting the field or substituting a non-empty placeholder.
4. The system shall not return vessel or exudate mask pixel data in this payload.

### Requirement 3: Zoomable fundus image with correctly mapped markers

**Objective:** As a reviewing clinician, I want to zoom into the fundus image and see markers track their true retinal positions, so that I can inspect a flagged region closely without the marker drifting off the anatomy it refers to.

#### Acceptance Criteria
1. When a clinician opens the viewer for a case with markers, the system shall display the fundus image with the optic disc, fovea, and microaneurysm candidates drawn at positions that correspond to their true locations in the image.
2. While a clinician zooms the image, the system shall keep every marker aligned to its true image position and shall scale marker sizes proportionally with zoom.
3. The system shall support zooming up to at least 3.5x the fitted size.
4. If a marker's coordinates fall outside the image bounds, the system shall not render that marker.
5. If markers are unavailable, the system shall still display the fundus image and shall state plainly that markers are unavailable for this case.

### Requirement 4: Drag-to-reveal wipe between plain and marked image

**Objective:** As a reviewing clinician, I want to wipe between the unmarked and marked view of the same image, so that I can confirm a marker's true position against the underlying anatomy.

#### Acceptance Criteria
1. When markers are available, the system shall provide a drag-controlled wipe that reveals the marked view over the plain view of the same image.
2. While the wipe is adjusted, the system shall keep the plain and marked layers at identical zoom and pan so that a marker's position under the wipe edge matches its position in the fully revealed view.
3. When markers are unavailable, the system shall not present a wipe that implies markers exist.

### Requirement 5: Honest unavailable and empty states

**Objective:** As a reviewing clinician, I want to be told plainly when markers cannot be shown and to see an honest empty state when none were found, so that I never mistake absence of evidence for a clean retina or for a working overlay.

#### Acceptance Criteria
1. If marker computation fails or the image is unretrievable, the system shall display a clear unavailable state and shall not draw any marker or decorative overlay.
2. If markers are successfully computed but no lesion candidates are present, the system shall display the image with anatomical landmarks only and shall state that no lesion candidates were found.
3. The system shall not present any decorative or synthetic overlay where markers are expected but unavailable.

### Requirement 6: Integration into the clinician review screen only

**Objective:** As a reviewing clinician, I want the viewer reachable from the review case I am already looking at, so that I can inspect markers without leaving my review workflow.

#### Acceptance Criteria
1. When a clinician is viewing a pending review case, the system shall provide an action to open the marker viewer for that case.
2. Opening the viewer shall not prevent the clinician from returning to the queue and submitting a sign-off decision.
3. A failure to load markers shall not block or delay the clinician's ability to submit a decision for that case.
4. The system shall not modify the operator-facing result screens owned by `screening-ux-consolidation`.

### Requirement 7: Test and quality-gate coverage

**Objective:** As a maintainer, I want automated proof that coordinate mapping, honesty, and fail-closed behaviour hold, so that a regression cannot silently misplace a marker or invent one.

#### Acceptance Criteria
1. The system shall include tests that verify a marker's computed display position matches its expected image-space position across zoom levels.
2. The system shall include tests that verify an unavailable or error condition renders no marker and no decorative overlay.
3. When the change is complete, the existing `pytest tests` and `flutter test` suites shall remain green, and the analysis pass shall report no new issues.
