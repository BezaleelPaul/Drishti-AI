from __future__ import annotations

import json
import sqlite3
from datetime import datetime
import uuid
from typing import List, Optional
from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, Depends
from fastapi.concurrency import run_in_threadpool
from api.auth import ApiPrincipal, audit_action, require_auth


from api.database import get_db, save_screening_record
from api.schemas import RetinalAnalysisResponse, RetinalQualityResponse
from api.services.ai_bridge import AIBridge
from src.classification.classifier import ClinicalModelUnavailableError

router = APIRouter(tags=["Retinal Screening"])

_UPLOAD_MAX_BYTES = 10 * 1024 * 1024
_UPLOAD_CHUNK = 256 * 1024


async def _read_upload_capped(file: UploadFile, what: str = "image") -> bytes:
    """Read an upload in chunks with an early abort: a lying or missing
    Content-Length (e.g. chunked encoding) must not OOM the worker before
    the size check runs."""
    parts = []
    total = 0
    while True:
        chunk = await file.read(_UPLOAD_CHUNK)
        if not chunk:
            break
        total += len(chunk)
        if total > _UPLOAD_MAX_BYTES:
            raise HTTPException(status_code=413, detail=f"{what.capitalize()} too large (max 10MB).")
        parts.append(chunk)
    data = b"".join(parts)
    if not data:
        raise HTTPException(status_code=400, detail=f"Empty {what} file uploaded.")
    return data


def _safe_json_list(value) -> list:
    """Parse a JSON list column; return [] on NULL/garbage instead of 500."""
    if not value:
        return []
    if isinstance(value, list):
        return value
    try:
        parsed = json.loads(value)
        return parsed if isinstance(parsed, list) else []
    except (json.JSONDecodeError, TypeError):
        return []


@router.post("/retinal/quality", response_model=RetinalQualityResponse)
async def check_image_quality(_principal: ApiPrincipal = Depends(require_auth),
    file: UploadFile = File(..., description="Fundus image (JPG/PNG)"),
    camera_profile: str = Form("Generic Fundus Camera"),
):
    """
    Model 1: Real-Time Retinal Image Quality Gate.
    Evaluates blur, illumination, contrast, FOV, and deep ensemble gradability in <100ms.
    Returns immediate ASHA guidance and Hindi voice tip if image fails.
    """
    if file.content_type not in ("image/jpeg", "image/png", "application/octet-stream"):
        raise HTTPException(status_code=400, detail=f"Unsupported content type: {file.content_type}. Upload JPG/PNG.")
    image_bytes = await _read_upload_capped(file)

    bridge = AIBridge.get_instance()
    try:
        # Blocking TF/OpenCV inference must not run on the event loop:
        # concurrent uploads would stall every other request behind it.
        quality_result = await run_in_threadpool(
            bridge.assess_quality, image_bytes, camera_profile)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return RetinalQualityResponse(**quality_result)


@router.post("/retinal/analyze", response_model=RetinalAnalysisResponse)
async def analyze_retinal_image(_principal: ApiPrincipal = Depends(require_auth),
    file: UploadFile = File(..., description="Fundus image (JPG/PNG)"),
    patient_id: str = Form(..., description="Target patient identifier"),
    eye_side: str = Form("Right", description="'Right' or 'Left'"),
    camera_profile: str = Form("Generic Fundus Camera"),
):
    """
    End-to-End AI Retinal Screening Analysis:
    1. Model 1 Quality Gate (rejection gate / zero diagnostic leakage)
    2. Model 2 DR Severity Classification (Grades 0 to 4)
    3. True Grad-CAM++ Explainability visualization
    4. Softmax Confidence margin evaluation & Clinical human review flagging
    5. Automatic enrollment into Doctor Review queue if flagged
    """
    if eye_side not in ("Right", "Left"):
        raise HTTPException(status_code=422, detail="eye_side must be 'Right' or 'Left'.")
    if file.content_type not in ("image/jpeg", "image/png", "application/octet-stream"):
        raise HTTPException(status_code=400, detail=f"Unsupported content type: {file.content_type}. Upload JPG/PNG.")
    image_bytes = await _read_upload_capped(file)

    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT patient_id FROM patients WHERE patient_id = ?", (patient_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail=f"Patient {patient_id} not registered.")

    bridge = AIBridge.get_instance()
    try:
        analysis = await run_in_threadpool(
            bridge.analyze_retina,
            image_bytes,
            patient_id,
            eye_side,
            camera_profile,
        )
    except ClinicalModelUnavailableError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        with get_db() as conn:
            save_screening_record(conn, analysis)
    except sqlite3.IntegrityError:
        # Patient deleted between the existence check and the save (FK).
        raise HTTPException(status_code=409, detail=f"Patient {patient_id} no longer registered; re-register and retry.")
    except ValueError as e:
        raise HTTPException(status_code=500, detail="Screening completed but persistence failed.")

    return RetinalAnalysisResponse(**analysis)


@router.get("/screenings/{patient_id}", response_model=List[RetinalAnalysisResponse])
def get_patient_screenings(
    patient_id: str,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    _principal: ApiPrincipal = Depends(require_auth),
):
    """Retrieves past retinal screening records for a specific patient (paginated)."""
    audit_action(_principal, "screening_list_read", patient_id)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("""
        SELECT * FROM screenings
        WHERE patient_id = ?
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
        """, (patient_id, limit, offset))
        rows = cursor.fetchall()

    results = []
    for r in rows:
        ref = r["is_referable"]
        stored_summary = r["patient_summary"] if "patient_summary" in r.keys() else None
        results.append(RetinalAnalysisResponse(
            screening_id=r["screening_id"],
            patient_id=r["patient_id"],
            eye_side=r["eye_side"],
            camera_profile=r["camera_profile"],
            quality_grade=r["quality_grade"],
            quality_score=r["quality_score"] if r["quality_score"] is not None else 0.0,
            # BORDERLINE with a stored DR grade was cleared by reassessment
            # (failed borderlines store no grade) — counts as passed.
            quality_passed=(r["quality_grade"] == "GOOD" or r["dr_grade_num"] is not None),
            rejection_reasons=_safe_json_list(r["rejection_reasons"]),
            suspected_clinical_cause=r["suspected_clinical_cause"],
            dr_grade=r["dr_grade_num"],
            dr_label=r["dr_grade_label"],
            prediction_score=r["dr_confidence"],
            probabilities=_safe_json_list(r["probabilities"]) or None,
            # Backend is not persisted for history rows: None = unknown,
            # never silently claimed as a real model.
            model_backend=None,
            # NULL in DB = ungradable: must stay None, never False (healthy).
            is_referable=None if ref is None else bool(ref),
            vessel_density_pct=r["vessel_density_pct"],
            microaneurysm_count=r["microaneurysm_count"],
            csme_risk=r["csme_risk"],
            min_fovea_distance_px=r["min_fovea_distance_px"],
            requires_human_review=bool(r["requires_human_review"]),
            human_review_type=r["human_review_type"] or "NONE",
            human_review_reason=r["human_review_reason"],
            confidence_flags=_safe_json_list(r["confidence_flags"]),
            original_image_url=r["original_image_path"],
            gradcam_overlay_url=r["gradcam_overlay_path"],
            gradcam_target_layer=r["target_layer"],
            action_recommendation=r["action_recommendation"] or "",
            # Stored verbatim: never re-fabricate a "Grade X detected"
            # summary for rows that have no grade.
            patient_plain_language_summary=(
                stored_summary
                or ("Screening completed. No gradable result; recapture advised."
                    if r["dr_grade_num"] is None else "Screening completed.")
            ),
            created_at=r["created_at"],
            captured_at=r["captured_at"] if "captured_at" in r.keys() else None,
        ))

    return results
