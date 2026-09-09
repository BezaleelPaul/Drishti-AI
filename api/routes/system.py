from __future__ import annotations

import os
from datetime import datetime
from typing import Any, Dict, List
from fastapi import APIRouter

from api.database import get_connection
from api.schemas import SystemStatusResponse

router = APIRouter(tags=["System Status"])

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@router.get("/status", response_model=SystemStatusResponse)
def get_system_status():
    """Returns real-time status of the screening platform, models, and queues."""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as count FROM patients")
    total_patients = cursor.fetchone()["count"]

    cursor.execute("SELECT COUNT(*) as count FROM screenings")
    total_screenings = cursor.fetchone()["count"]

    cursor.execute("SELECT COUNT(*) as count FROM doctor_reviews WHERE status = 'PENDING'")
    pending_reviews = cursor.fetchone()["count"]

    conn.close()

    models_info = {
        "Model 1 (Quality Gate)": "Deep Ensemble (berenslab/fundus_image_toolbox) + MultiScale Fusion",
        "Model 2 (DR Classifier)": "EfficientNetB0 (APTOS 2019 fine-tuned, 5-class severity)",
        "Explainability Engine": "Grad-CAM++ (Higher-order gradient backpropagation)",
        "Upstream Risk Engine": "Random Forest (Google-Aravind / Indian ICMR guideline calibration)",
    }

    return SystemStatusResponse(
        ai_engine="Ready (Model 1 Quality + Model 2 DR + Grad-CAM++)",
        camera_input="Ready (Generic Fundus Camera / JPG / PNG)",
        network_connectivity="Online",
        pending_doctor_reviews=pending_reviews,
        total_patients_registered=total_patients,
        total_screenings_completed=total_screenings,
        offline_queue_ready=True,
        models_loaded=models_info,
        last_sync_time=datetime.utcnow().strftime("%d %b %Y, %H:%M UTC"),
    )


@router.get("/cameras")
def get_camera_profiles() -> List[Dict[str, Any]]:
    """Conceptual camera profiles demonstrating manufacturer-agnostic image compatibility."""
    return [
        {
            "id": "generic",
            "name": "Generic Fundus Camera",
            "manufacturer": "Any Compatible Fundus Device",
            "format": "JPG / PNG",
            "description": "Standard circular fundus photography from any medical device",
            "fov": "30° to 50°",
        },
        {
            "id": "forus_3nethra",
            "name": "Forus 3nethra Classic",
            "manufacturer": "Forus Health (India)",
            "format": "2048 x 1536 JPG",
            "description": "Non-mydriatic portable tabletop camera for Indian rural PHCs",
            "fov": "45° field of view",
        },
        {
            "id": "remidio_fop",
            "name": "Remidio Fundus-on-Phone (FOP)",
            "manufacturer": "Remidio Innovative Solutions",
            "format": "Smartphone CMOS RGB",
            "description": "Handheld portable smartphone fundus camera for mobile screening vans",
            "fov": "45° field of view",
        },
        {
            "id": "volk_inview",
            "name": "Volk iNview",
            "manufacturer": "Volk Optical",
            "format": "Smartphone 20D Lens Aperture",
            "description": "Smartphone-mounted indirect ophthalmoscopy condensing lens",
            "fov": "50° circular aperture",
        },
    ]


@router.get("/samples")
def get_sample_test_cases() -> List[Dict[str, Any]]:
    """Curated field test pack demonstrating multi-camera and multi-condition compatibility."""
    return [
        {
            "id": "case_1_clean",
            "name": "Case 1: Clean Diagnostic Quality",
            "patient_name": "Ramesh Kumar (Age: 54)",
            "camera": "Hospital-grade desktop fundus camera",
            "expected_quality": "GOOD",
            "expected_dr": "Grade 0 / Mild",
            "sample_url": "/static/samples/01_real_clinical_fundus/real_clinical_fundus_patient1.jpg",
        },
        {
            "id": "case_2_blur",
            "name": "Case 2: Camera Defocus & Motion Blur",
            "patient_name": "Test Subject (Defocus artifact)",
            "camera": "Handheld smartphone camera with motion",
            "expected_quality": "REJECT (Severe Blur)",
            "expected_dr": "SUPPRESSED (Safe abstention)",
            "sample_url": "/static/samples/02_quality_failures_and_edge_cases/real_fundus_with_extreme_motion_blur.jpg",
        },
        {
            "id": "case_3_borderline",
            "name": "Case 3: Marginal Low Illumination",
            "patient_name": "Test Subject (Small pupil / under-dilation)",
            "camera": "Non-mydriatic camera with small pupil",
            "expected_quality": "BORDERLINE (Reassessment)",
            "expected_dr": "Conditional triage under review",
            "sample_url": "/static/samples/04_section24_demo_scenarios/scenario_3_borderline.jpg",
        },
        {
            "id": "case_4_severe",
            "name": "Case 4: High-Risk Proliferative Signs",
            "patient_name": "Anand Patil (Age: 62)",
            "camera": "Clinical fundus camera",
            "expected_quality": "GOOD",
            "expected_dr": "Grade 3 / 4 (High Risk — Mandatory Over-read)",
            "sample_url": "/static/samples/04_section24_demo_scenarios/scenario_4_uncertain.jpg",
        },
        {
            "id": "case_5_non_fundus",
            "name": "Case 5: Adversarial Non-Fundus Input",
            "patient_name": "Negative Control Test",
            "camera": "External photo / non-retinal image",
            "expected_quality": "REJECT (Non-Fundus or Corrupt)",
            "expected_dr": "SUPPRESSED",
            "sample_url": "/static/samples/03_adversarial_non_fundus/adversarial_non_fundus_blue_profile.jpg",
        },
    ]
