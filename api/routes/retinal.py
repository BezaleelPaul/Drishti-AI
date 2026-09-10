from __future__ import annotations

import json
from datetime import datetime
import uuid
from typing import List, Optional
from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from api.database import get_connection
from api.schemas import RetinalAnalysisResponse, RetinalQualityResponse
from api.services.ai_bridge import AIBridge

router = APIRouter(tags=["Retinal Screening"])


@router.post("/retinal/quality", response_model=RetinalQualityResponse)
async def check_image_quality(
    file: UploadFile = File(..., description="Fundus image (JPG/PNG)"),
    camera_profile: str = Form("Generic Fundus Camera"),
):
    """
    Model 1: Real-Time Retinal Image Quality Gate.
    Evaluates blur, illumination, contrast, FOV, and deep ensemble gradability in <100ms.
    Returns immediate ASHA guidance and Hindi voice tip if image fails.
    """
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image file uploaded.")

    bridge = AIBridge.get_instance()
    quality_result = bridge.assess_quality(image_bytes, camera_profile=camera_profile)
    return RetinalQualityResponse(**quality_result)


@router.post("/retinal/analyze", response_model=RetinalAnalysisResponse)
async def analyze_retinal_image(
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
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image file uploaded.")

    # Validate patient exists (or auto-register from mobile ASHA client)
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT patient_id FROM patients WHERE patient_id = ?", (patient_id,))
    if not cursor.fetchone():
        now_ts = datetime.utcnow().isoformat() + "Z"
        cursor.execute("""
        INSERT INTO patients (
            patient_id, name, age, gender, phone, village, screening_centre,
            known_diabetes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            patient_id, f"Patient {patient_id}", 52, "Unknown", "+91 98000 00000",
            "Field PHC", "Rural Screening Camp", "Yes", now_ts
        ))
        conn.commit()

    bridge = AIBridge.get_instance()
    analysis = bridge.analyze_retina(
        image_bytes=image_bytes,
        patient_id=patient_id,
        eye_side=eye_side,
        camera_profile=camera_profile,
    )

    # Persist screening record
    cursor.execute("""
    INSERT INTO screenings (
        screening_id, patient_id, eye_side, camera_profile, quality_grade,
        quality_score, rejection_reasons, suspected_clinical_cause,
        dr_grade_num, dr_grade_label, dr_confidence, is_referable,
        requires_human_review, human_review_type, human_review_reason,
        original_image_path, gradcam_overlay_path, target_layer,
        action_recommendation, screening_status, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        analysis["screening_id"],
        analysis["patient_id"],
        analysis["eye_side"],
        analysis["camera_profile"],
        analysis["quality_grade"],
        analysis["quality_score"],
        json.dumps(analysis["rejection_reasons"]),
        analysis["suspected_clinical_cause"],
        analysis["dr_grade"],
        analysis["dr_label"],
        analysis["prediction_score"],
        1 if analysis["is_referable"] else 0,
        1 if analysis["requires_human_review"] else 0,
        analysis["human_review_type"],
        analysis["human_review_reason"],
        analysis["original_image_url"],
        analysis["gradcam_overlay_url"],
        analysis["gradcam_target_layer"],
        analysis["action_recommendation"],
        "Completed",
        analysis["created_at"],
    ))

    # If human review required, create pending doctor review queue item
    if analysis["requires_human_review"]:
        review_id = f"REV-{uuid.uuid4().hex[:6].upper()}"
        cursor.execute("""
        INSERT INTO doctor_reviews (
            review_id, screening_id, patient_id, status, created_at
        ) VALUES (?, ?, ?, 'PENDING', ?)
        """, (
            review_id,
            analysis["screening_id"],
            analysis["patient_id"],
            analysis["created_at"],
        ))

    conn.commit()
    conn.close()

    return RetinalAnalysisResponse(**analysis)


@router.get("/screenings/{patient_id}", response_model=List[RetinalAnalysisResponse])
def get_patient_screenings(patient_id: str):
    """Retrieves all past retinal screening records for a specific patient."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
    SELECT * FROM screenings
    WHERE patient_id = ?
    ORDER BY created_at DESC
    """, (patient_id,))
    rows = cursor.fetchall()
    conn.close()

    results = []
    for r in rows:
        results.append(RetinalAnalysisResponse(
            screening_id=r["screening_id"],
            patient_id=r["patient_id"],
            eye_side=r["eye_side"],
            camera_profile=r["camera_profile"],
            quality_grade=r["quality_grade"],
            quality_score=r["quality_score"] or 0.0,
            quality_passed=r["quality_grade"] == "GOOD",
            rejection_reasons=json.loads(r["rejection_reasons"] or "[]"),
            suspected_clinical_cause=r["suspected_clinical_cause"],
            dr_grade=r["dr_grade_num"],
            dr_label=r["dr_grade_label"],
            prediction_score=r["dr_confidence"],
            is_referable=bool(r["is_referable"]),
            requires_human_review=bool(r["requires_human_review"]),
            human_review_type=r["human_review_type"] or "NONE",
            human_review_reason=r["human_review_reason"],
            original_image_url=r["original_image_path"],
            gradcam_overlay_url=r["gradcam_overlay_path"],
            gradcam_target_layer=r["target_layer"],
            action_recommendation=r["action_recommendation"] or "",
            patient_plain_language_summary=(
                f"Grade {r['dr_grade_num']} detected. Doctor review assigned."
                if r["dr_grade_num"] is not None else "Screening completed."
            ),
            created_at=r["created_at"],
        ))

    return results
