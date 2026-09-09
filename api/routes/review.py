from __future__ import annotations

from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, HTTPException

from api.database import get_connection
from api.schemas import (
    DoctorDecisionRequest,
    DoctorDecisionResponse,
    DoctorReviewItem,
    DoctorReviewListResponse,
)

router = APIRouter(prefix="/review", tags=["Doctor Review"])


@router.get("/pending", response_model=DoctorReviewListResponse)
def get_pending_reviews():
    """
    Retrieves all screenings flagged for clinical review:
    - Ambiguous or low-confidence predictions (<60%)
    - High-risk cases (Severe NPDR, Proliferative DR)
    - Borderline quality scans requiring specialist over-read
    """
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
    SELECT 
        r.review_id, r.screening_id, r.patient_id, r.status, r.doctor_name,
        r.doctor_decision, r.clinical_notes, r.referral_urgency, r.follow_up_days,
        r.created_at, r.reviewed_at,
        p.name as patient_name, p.age as patient_age, p.gender as patient_gender, p.village,
        s.eye_side, s.quality_grade, s.dr_grade_num, s.dr_grade_label, s.dr_confidence,
        s.is_referable, s.requires_human_review, s.human_review_type, s.human_review_reason,
        s.original_image_path, s.gradcam_overlay_path
    FROM doctor_reviews r
    JOIN patients p ON r.patient_id = p.patient_id
    JOIN screenings s ON r.screening_id = s.screening_id
    WHERE r.status = 'PENDING'
    ORDER BY r.created_at ASC
    """)
    rows = cursor.fetchall()
    conn.close()

    items = []
    for r in rows:
        items.append(DoctorReviewItem(
            review_id=r["review_id"],
            screening_id=r["screening_id"],
            patient_id=r["patient_id"],
            patient_name=r["patient_name"],
            patient_age=r["patient_age"],
            patient_gender=r["patient_gender"],
            village=r["village"],
            eye_side=r["eye_side"],
            quality_grade=r["quality_grade"],
            dr_grade_num=r["dr_grade_num"],
            dr_grade_label=r["dr_grade_label"],
            dr_confidence=r["dr_confidence"],
            is_referable=bool(r["is_referable"]),
            requires_human_review=bool(r["requires_human_review"]),
            human_review_type=r["human_review_type"] or "CLINICAL_LEVEL",
            human_review_reason=r["human_review_reason"],
            original_image_url=r["original_image_path"],
            gradcam_overlay_url=r["gradcam_overlay_path"],
            status=r["status"],
            doctor_name=r["doctor_name"],
            doctor_decision=r["doctor_decision"],
            clinical_notes=r["clinical_notes"],
            referral_urgency=r["referral_urgency"],
            follow_up_days=r["follow_up_days"],
            created_at=r["created_at"],
            reviewed_at=r["reviewed_at"],
        ))

    return DoctorReviewListResponse(total_pending=len(items), items=items)


@router.post("/{review_id}", response_model=DoctorDecisionResponse)
def submit_doctor_decision(review_id: str, payload: DoctorDecisionRequest):
    """
    Records an ophthalmologist's clinical verdict.
    The doctor remains the final authority, able to confirm, override, or request repeat capture.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT review_id, status FROM doctor_reviews WHERE review_id = ?", (review_id,))
    row = cursor.fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail=f"Review case {review_id} not found.")

    now = datetime.utcnow().isoformat() + "Z"
    new_status = payload.decision.upper()

    cursor.execute("""
    UPDATE doctor_reviews
    SET status = ?,
        doctor_name = ?,
        doctor_decision = ?,
        doctor_grade_override = ?,
        clinical_notes = ?,
        referral_urgency = ?,
        follow_up_days = ?,
        reviewed_at = ?
    WHERE review_id = ?
    """, (
        new_status,
        payload.doctor_name,
        payload.decision,
        payload.grade_override,
        payload.clinical_notes,
        payload.referral_urgency,
        payload.follow_up_days,
        now,
        review_id,
    ))

    conn.commit()
    conn.close()

    return DoctorDecisionResponse(
        success=True,
        message=f"Clinical decision recorded by {payload.doctor_name}.",
        review_id=review_id,
        updated_status=new_status,
    )
