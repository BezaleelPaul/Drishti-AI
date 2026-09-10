"""
Verification suite for FastAPI endpoints.
Tests /status, /cameras, /samples, /patients, and /diabetes-risk.
"""
import os
import sys

# Ensure repository root is in sys.path
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from fastapi.testclient import TestClient
from api.main import app

client = TestClient(app)
# Dev defaults match the backend non-prod keys; override per deployment.
OP = {"X-API-Key": os.environ.get("DRISHTI_API_KEY_OP", "dev-operator-key")}
DR = {"X-API-Key": os.environ.get("DRISHTI_API_KEY_DR", "dev-doctor-key")}

def run_api_checks():
    print("=" * 60)
    print("VERIFYING NETRA-AI FASTAPI BACKEND BRIDGE")
    print("=" * 60)

    # 1. Root & Status
    r = client.get("/")
    assert r.status_code == 200, f"Root failed: {r.text}"
    print(f"[PASS] GET / -> Status: {r.json()['status']}")

    r = client.get("/status", headers=OP)
    assert r.status_code == 200, f"Status failed: {r.text}"
    data = r.json()
    print(f"[PASS] GET /status -> Engine: {data['ai_engine']} (Patients: {data['total_patients_registered']})")

    # 2. Camera Profiles & Samples
    r = client.get("/cameras")
    assert r.status_code == 200
    cameras = r.json()
    assert len(cameras) >= 4
    print(f"[PASS] GET /cameras -> {len(cameras)} hardware profiles registered")

    r = client.get("/samples")
    assert r.status_code == 200
    samples = r.json()
    assert len(samples) >= 5
    print(f"[PASS] GET /samples -> {len(samples)} field test cases available")

    # 0. Unauthenticated access must be rejected
    r = client.get("/patients")
    assert r.status_code == 401, f"Unauthenticated PHI access not blocked: {r.status_code}"
    print("[PASS] GET /patients without key -> 401 Unauthorized")
    r = client.get("/status")
    assert r.status_code == 401, f"Unauthenticated /status not blocked: {r.status_code}"
    print("[PASS] GET /status without key -> 401 Unauthorized")

    # 3. Patients API
    r = client.get("/patients", headers=OP)
    assert r.status_code == 200
    p_data = r.json()
    assert p_data["total"] >= 1
    print(f"[PASS] GET /patients -> {p_data['total']} registered patients found")

    # Test patient registration (unique contact IDs per run — no DB pile-up)
    import uuid as _uuid
    _uniq = _uuid.uuid4().hex[:8]
    new_patient = {
        "name": "Kavita Shinde",
        "age": 52,
        "gender": "Female",
        "phone": f"+91 9{_uniq[:4]} {_uniq[4:]}",
        "abha_id": f"91-{_uniq[:4]}-9901-4455",
        "village": "Saswad, Purandar",
        "screening_centre": "Saswad Primary Health Centre",
        "known_diabetes": "Yes",
        "diabetes_duration_years": 4.0,
        "hba1c": 7.8,
        "fasting_glucose": 145.0,
        "bmi": 27.2,
        "family_history": True,
        "physical_activity": "Moderate",
        "symptoms": ["Mild fatigue"],
    }
    r = client.post("/patients", json=new_patient, headers=OP)
    assert r.status_code == 201, f"Create patient failed: {r.text}"
    created_id = r.json()["patient_id"]
    print(f"[PASS] POST /patients -> Created patient: {created_id}")

    # 4. Upstream Diabetes Risk
    risk_payload = {
        "patient_id": created_id,
        "age": 52,
        "gender": "Female",
        "bmi": 27.2,
        "family_history": True,
        "physical_activity": "Moderate",
        "symptoms": ["Mild fatigue"],
        "hba1c": 7.8,
        "fasting_glucose": 145.0,
        "known_diabetes_years": 4.0,
    }
    r = client.post("/diabetes-risk", json=risk_payload, headers=OP)
    assert r.status_code == 200, f"Diabetes risk failed: {r.text}"
    risk_res = r.json()
    print(f"[PASS] POST /diabetes-risk -> Risk: {risk_res['risk_level']} (Score: {risk_res['risk_score']})")

    # 5. Retinal Quality Check on Clean Sample
    sample_file = os.path.join(PROJECT_ROOT, "test_samples", "04_section24_demo_scenarios", "scenario_1_good.jpg")
    if not os.path.isfile(sample_file):
        raise FileNotFoundError(f"Required API-check sample missing: {sample_file}")
    with open(sample_file, "rb") as f:
        r = client.post("/retinal/quality", files={"file": ("good.jpg", f, "image/jpeg")}, headers=OP)
        assert r.status_code == 200, f"Quality check failed: {r.text}"
        q_res = r.json()
        print(f"[PASS] POST /retinal/quality -> Grade: {q_res['quality_grade']} (Score: {q_res['quality_score']:.2f})")

    # 6. Full Retinal Analysis with Grad-CAM++
    with open(sample_file, "rb") as f:
        r = client.post(
            "/retinal/analyze",
            data={"patient_id": created_id, "eye_side": "Right", "camera_profile": "Generic Fundus Camera"},
            files={"file": ("good.jpg", f, "image/jpeg")},
            headers=OP,
        )
        assert r.status_code == 200, f"Analyze failed: {r.text}"
        a_res = r.json()
        print(f"[PASS] POST /retinal/analyze -> Screening ID: {a_res['screening_id']}")
        print(f"       DR Grade: {a_res['dr_grade']} ({a_res['dr_label']})")
        print(f"       Grad-CAM Layer: {a_res['gradcam_target_layer']}")
        print(f"       Human Review: {a_res['requires_human_review']} ({a_res['human_review_type']})")

    # 7. Doctor Review Queue
    r = client.get("/review/pending", headers=DR)
    assert r.status_code == 200
    rev_data = r.json()
    print(f"[PASS] GET /review/pending -> {rev_data['total_pending']} cases awaiting ophthalmologist review")

    print("=" * 60)
    print("ALL FASTAPI BACKEND BRIDGE CHECKS PASSED!")
    print("=" * 60)

if __name__ == "__main__":
    run_api_checks()
