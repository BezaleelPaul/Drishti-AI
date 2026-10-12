"""Integration tests for GET /review/{review_id}/markers (task 2.2).

Covers the MarkerRoute API contract (design.md: 200 marker payload, 404
unknown review, 401/403 auth, 200-unavailable on segmentation failure) and
the audit-trail behaviour for reads and misses.

Design decision (documented per spec): the route PRE-CHECKS the review case
(Option A) — a strict review-id format check plus a `SELECT 1 FROM
doctor_reviews` lookup — and raises 404 itself. The marker service stays
fail-closed for any TOCTOU race (row deleted between pre-check and compute),
so no typed exception had to be added to marker_service.
"""

import os
import sqlite3
import tempfile
from datetime import datetime, timezone

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from api import database
from api.main import app

client = TestClient(app, raise_server_exceptions=False)
DOCTOR_HEADERS = {"X-API-Key": "dev-doctor-key"}
OPERATOR_HEADERS = {"X-API-Key": "dev-operator-key"}

W, H = 640, 480
REVIEW_ID = "REV-ROUTE1"
SCREENING_ID = "SCR-ROUTE1"
MA_DOTS = (
    (430, 310),
    (350, 340),
    (440, 160),
    (300, 150),
    (500, 260),
    (260, 350),
    (390, 120),
)

EXPECTED_KEYS = {
    "review_id",
    "available",
    "reason",
    "source",
    "width",
    "height",
    "optic_disc",
    "fovea",
    "ma_candidates",
}


def _synthetic_fundus_rgb() -> np.ndarray:
    """Black background, bright red fundus disc, darker vessel strokes,
    small dark-red MA-like dots — the same REAL segmenter exercise used by
    tests/unit/test_review_markers_service.py."""
    img = np.zeros((H, W, 3), dtype=np.uint8)
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


def _seed_review_case(image_path: str | None) -> None:
    now = datetime.now(timezone.utc).isoformat()
    conn = sqlite3.connect(database.DB_PATH)
    try:
        conn.execute(
            "INSERT INTO patients (patient_id, name, age, gender, created_at) "
            "VALUES ('PT-ROUTE1', 'Marker Route Probe', 50, 'Male', ?)",
            (now,),
        )
        conn.execute(
            "INSERT INTO screenings (screening_id, patient_id, eye_side, "
            "quality_grade, created_at, original_image_path) "
            "VALUES (?, 'PT-ROUTE1', 'Right', 'GOOD', ?, ?)",
            (SCREENING_ID, now, image_path),
        )
        conn.execute(
            "INSERT INTO doctor_reviews (review_id, screening_id, patient_id, "
            "status, created_at) VALUES (?, ?, 'PT-ROUTE1', 'PENDING', ?)",
            (REVIEW_ID, SCREENING_ID, now),
        )
        conn.commit()
    finally:
        conn.close()


@pytest.fixture()
def review_env(monkeypatch):
    """Temp SQLite DB + temp image root; DB globals restored afterwards."""
    orig_path = database.DB_PATH
    orig_done = database._init_done
    monkeypatch.setenv("SEED_DEMO_DATA", "0")
    with tempfile.TemporaryDirectory(prefix="marker-route-") as td:
        database.DB_PATH = os.path.join(td, "test.db")
        database._init_done = False
        database.init_db()
        yield td
    database.DB_PATH = orig_path
    database._init_done = orig_done


def _audit_rows(action: str) -> list[sqlite3.Row]:
    conn = sqlite3.connect(database.DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        return conn.execute(
            "SELECT actor, action, resource, detail FROM audit_log WHERE action = ?",
            (action,),
        ).fetchall()
    finally:
        conn.close()


def test_doctor_key_gets_marker_payload_for_seeded_case(review_env):
    """Req 1.1/6.3: doctor key -> 200 payload with dimensions, coordinates
    only (no mask keys), provenance pinned, and a read audit row."""
    image_path = _write_fundus_file(review_env)
    _seed_review_case(image_path)

    response = client.get(f"/review/{REVIEW_ID}/markers", headers=DOCTOR_HEADERS)

    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body.keys()) == EXPECTED_KEYS
    assert body["review_id"] == REVIEW_ID
    assert body["available"] is True
    assert body["source"] == "classical_cv_segmentation"
    assert (body["width"], body["height"]) == (W, H)
    for marker in body["ma_candidates"]:
        assert isinstance(marker["x"], int) and isinstance(marker["y"], int)
        assert isinstance(marker["r"], int) and marker["r"] >= 0
        assert 0 <= marker["x"] < W
        assert 0 <= marker["y"] < H
    assert len(body["ma_candidates"]) == len(MA_DOTS)

    reads = _audit_rows("review_markers_read")
    assert len(reads) == 1
    assert reads[0]["resource"] == REVIEW_ID
    assert SCREENING_ID in reads[0]["detail"]
    assert reads[0]["actor"].startswith("doctor:")


def test_unknown_review_returns_404(review_env):
    _seed_review_case(None)

    response = client.get("/review/REV-NOEXIST/markers", headers=DOCTOR_HEADERS)

    assert response.status_code == 404, response.text
    assert "not found" in response.json()["detail"].lower()
    assert len(_audit_rows("review_markers_read_404")) == 1


def test_missing_auth_header_returns_401(review_env):
    response = client.get(f"/review/{REVIEW_ID}/markers")

    assert response.status_code == 401, response.text


def test_operator_key_returns_403(review_env):
    image_path = _write_fundus_file(review_env)
    _seed_review_case(image_path)

    response = client.get(f"/review/{REVIEW_ID}/markers", headers=OPERATOR_HEADERS)

    assert response.status_code == 403, response.text
    assert _audit_rows("review_markers_read") == []


def test_invalid_review_id_format_returns_404(review_env):
    """Invalid format NEVER exists -> uniform 404 without leaking the
    expected format in the message."""
    for junk in ("REV-SHORT", "garbage123", "%20%2e%2e"):
        response = client.get(f"/review/{junk}/markers", headers=DOCTOR_HEADERS)
        assert response.status_code == 404, (junk, response.text)
        assert response.json()["detail"] == "Review case not found."


def test_path_traversal_attempts_return_404_and_audit(review_env):
    """Traversal that survives client-side URL normalisation lands in the
    path param, fails the format check, is audited, and never touches the
    filesystem or DB. A %2F form decodes to a slash and is rejected one
    layer earlier by routing itself — still a 404, but no handler audit."""
    for injected in ("%2e%2e", "%20%2e%2e"):
        response = client.get(f"/review/{injected}/markers", headers=DOCTOR_HEADERS)
        assert response.status_code == 404, (injected, response.text)
    assert len(_audit_rows("review_markers_read_404")) == 2
    response = client.get("/review/..%2Fetc%2Fpasswd/markers", headers=DOCTOR_HEADERS)
    assert response.status_code == 404, response.text


def test_segmentation_failure_is_200_unavailable_not_5xx(review_env, monkeypatch):
    """Design contract: a segmentation failure is a SUCCESSFUL response
    carrying an unavailable payload, never a server error."""
    from src.segmentation.structure_segmenter import RetinalStructureSegmenter

    image_path = _write_fundus_file(review_env)
    _seed_review_case(image_path)

    def _boom(self, np_img):
        raise RuntimeError("segmenter exploded")

    monkeypatch.setattr(RetinalStructureSegmenter, "segment_structures", _boom)
    response = client.get(f"/review/{REVIEW_ID}/markers", headers=DOCTOR_HEADERS)

    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body.keys()) == EXPECTED_KEYS
    assert body["available"] is False
    assert isinstance(body["reason"], str) and body["reason"]
    assert body["source"] == "classical_cv_segmentation"
    assert body["width"] == 0 and body["height"] == 0
    assert body["optic_disc"] is None and body["fovea"] is None
    assert body["ma_candidates"] == []
