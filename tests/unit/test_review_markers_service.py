"""Unit tests for the on-demand review marker service (compute_review_markers).

Consistency strategy: the service's payload is asserted against a DIRECT
RetinalStructureSegmenter call on the same decoded image — coordinates are
real algorithm output, so the tests prove faithful mapping (types, bounds,
counts, identity of coordinates) instead of hardcoding coordinate values.
"""

import os
import sqlite3
import tempfile
from datetime import datetime, timezone

import cv2
import numpy as np
import pytest
from PIL import Image

from api.schemas import ReviewMarkersResponse
from src.services.marker_service import _get_segmenter, compute_review_markers

W, H = 640, 480
REVIEW_ID = "REV-TEST1"
SCREENING_ID = "SCR-TEST1"
MA_DOTS = (
    (430, 310),
    (350, 340),
    (440, 160),
    (300, 150),
    (500, 260),
    (260, 350),
    (390, 120),
)


def _synthetic_fundus_rgb() -> np.ndarray:
    """Black background, bright red fundus disc, darker vessel strokes,
    small dark-red MA-like dots — synthetic pixels exercising REAL segmenter
    code (never a stub)."""
    img = np.zeros((H, W, 3), dtype=np.uint8)  # channel order R,G,B
    cv2.circle(img, (320, 240), 200, (60, 30, 35), -1)
    cv2.circle(img, (240, 240), 28, (240, 210, 170), -1)
    cv2.line(img, (240, 240), (400, 180), (25, 14, 18), 2, cv2.LINE_AA)
    cv2.line(img, (240, 240), (180, 340), (25, 14, 18), 2, cv2.LINE_AA)
    for x, y in MA_DOTS:
        cv2.circle(img, (x, y), 2, (45, 10, 25), -1)
    return img


def _write_fundus_file(root: str, screening_id: str = SCREENING_ID) -> str:
    folder = os.path.join(root, "results", "api_screenings", screening_id)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"{screening_id}_orig.jpg")
    Image.fromarray(_synthetic_fundus_rgb()).save(path, quality=98)
    return path


def _seed_review_case(image_path: str | None, *, dangling_screening: bool = False) -> None:
    """Insert patient + screening + PENDING doctor_review rows into the
    fixture DB (raw SQL, mirroring test_retention's seeding style)."""
    import api.database as database

    now = datetime.now(timezone.utc).isoformat()
    conn = sqlite3.connect(database.DB_PATH)
    try:
        conn.execute(
            "INSERT INTO patients (patient_id, name, age, gender, created_at) "
            "VALUES ('PT-TEST1', 'Marker Probe', 50, 'Male', ?)",
            (now,),
        )
        if not dangling_screening:
            conn.execute(
                "INSERT INTO screenings (screening_id, patient_id, eye_side, "
                "quality_grade, created_at, original_image_path) "
                "VALUES (?, 'PT-TEST1', 'Right', 'GOOD', ?, ?)",
                (SCREENING_ID, now, image_path),
            )
        conn.execute(
            "INSERT INTO doctor_reviews (review_id, screening_id, patient_id, "
            "status, created_at) VALUES (?, ?, 'PT-TEST1', 'PENDING', ?)",
            (REVIEW_ID, SCREENING_ID, now),
        )
        conn.commit()
    finally:
        conn.close()


@pytest.fixture()
def review_env(monkeypatch):
    """Temp SQLite DB + temp image root; DB globals restored afterwards."""
    import api.database as database

    orig_path = database.DB_PATH
    orig_done = database._init_done
    monkeypatch.setenv("SEED_DEMO_DATA", "0")
    with tempfile.TemporaryDirectory(prefix="marker-svc-") as td:
        database.DB_PATH = os.path.join(td, "test.db")
        database._init_done = False
        database.init_db()
        yield td
    database.DB_PATH = orig_path
    database._init_done = orig_done


def _assert_unavailable(response: ReviewMarkersResponse) -> None:
    """Fail-closed shape: no coordinate values anywhere in the payload."""
    assert response.available is False
    assert isinstance(response.reason, str) and response.reason
    assert response.optic_disc is None
    assert response.fovea is None
    assert response.ma_candidates == []
    assert response.width == 0
    assert response.height == 0
    assert response.source == "classical_cv_segmentation"


def test_available_path_matches_direct_segmenter_output(review_env):
    """Req 1.1/1.2 + 2.1: on-demand segmentation maps the segmenter's real
    output faithfully (count + coordinate identity), never hardcoded."""
    image_path = _write_fundus_file(review_env)
    _seed_review_case(image_path)

    np_img = np.array(Image.open(image_path).convert("RGB"))
    direct = _get_segmenter().segment_structures(np_img)
    response = compute_review_markers(REVIEW_ID)

    assert response.available is True
    assert response.review_id == REVIEW_ID
    assert (response.width, response.height) == (np_img.shape[1], np_img.shape[0])
    assert response.source == "classical_cv_segmentation"

    od_x, od_y = direct.optic_disc_center
    if direct.optic_disc_radius > 0 and (od_x != 0 or od_y != 0):
        assert response.optic_disc is not None
        assert (response.optic_disc.x, response.optic_disc.y, response.optic_disc.r) == (
            int(od_x),
            int(od_y),
            int(direct.optic_disc_radius),
        )
    else:
        assert response.optic_disc is None

    fv_x, fv_y = direct.fovea_center
    if fv_x != 0 or fv_y != 0:
        assert response.fovea is not None
        assert (response.fovea.x, response.fovea.y) == (int(fv_x), int(fv_y))
    else:
        assert response.fovea is None

    assert len(response.ma_candidates) == len(direct.microaneurysm_candidates)
    for marker, (cx, cy, cr) in zip(response.ma_candidates, direct.microaneurysm_candidates):
        assert isinstance(marker.x, int) and isinstance(marker.y, int)
        assert isinstance(marker.r, int)
        assert (marker.x, marker.y, marker.r) == (int(cx), int(cy), int(cr))
        assert 0 <= marker.x < response.width
        assert 0 <= marker.y < response.height
        assert marker.r >= 0

    if not direct.microaneurysm_candidates:
        assert response.reason == "No microaneurysm candidates found"


def test_unknown_review_fails_closed(review_env):
    _assert_unavailable(compute_review_markers("REV-DOESNOTEXIST"))
    response = compute_review_markers("REV-DOESNOTEXIST")
    assert response.reason == "review case not found"


def test_review_with_missing_screening_row_fails_closed(review_env):
    _seed_review_case(None, dangling_screening=True)
    _assert_unavailable(compute_review_markers(REVIEW_ID))


def test_review_with_empty_image_path_fails_closed(review_env):
    _seed_review_case("")
    _assert_unavailable(compute_review_markers(REVIEW_ID))


def test_review_with_missing_image_file_fails_closed(review_env):
    _seed_review_case(os.path.join(review_env, "no_such_dir", "gone.jpg"))
    _assert_unavailable(compute_review_markers(REVIEW_ID))


def test_garbage_image_fails_closed(review_env):
    path = os.path.join(review_env, "garbage.jpg")
    with open(path, "wb") as fh:
        fh.write(b"this is not an image at all")
    _seed_review_case(path)
    _assert_unavailable(compute_review_markers(REVIEW_ID))


def test_oversize_header_fails_closed_before_pixel_decode(review_env):
    """Header dimension cap: a >4096px image is rejected before decode."""
    huge = np.zeros((10, 4097, 3), dtype=np.uint8)
    path = os.path.join(review_env, "wide.jpg")
    Image.fromarray(huge).save(path, quality=95)
    _seed_review_case(path)
    _assert_unavailable(compute_review_markers(REVIEW_ID))


def test_segmenter_exception_fails_closed(review_env, monkeypatch):
    from src.segmentation.structure_segmenter import RetinalStructureSegmenter

    image_path = _write_fundus_file(review_env)
    _seed_review_case(image_path)

    def _boom(self, np_img):
        raise RuntimeError("segmenter exploded")

    monkeypatch.setattr(RetinalStructureSegmenter, "segment_structures", _boom)
    _assert_unavailable(compute_review_markers(REVIEW_ID))


def test_payload_never_carries_mask_data(review_env):
    """Req 2.4: coordinates only — no mask/overlay/attention fields."""
    image_path = _write_fundus_file(review_env)
    _seed_review_case(image_path)
    dumped = compute_review_markers(REVIEW_ID).model_dump()
    for forbidden in (
        "vessel_mask",
        "exudate_mask",
        "annotated_overlay",
        "vessel_density_pct",
        "vessel_density_raw",
        "gradcam",
        "mask",
    ):
        assert forbidden not in dumped
