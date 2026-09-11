from fastapi.testclient import TestClient

from api.main import app


client = TestClient(app, raise_server_exceptions=False)
OPERATOR_HEADERS = {"X-API-Key": "dev-operator-key"}


def test_diabetes_risk_returns_provenance_for_rule_path():
    response = client.post(
        "/diabetes-risk",
        headers=OPERATOR_HEADERS,
        json={
            "age": 52,
            "gender": "Female",
            "bmi": 27.2,
            "family_history": True,
            "known_diabetes_years": 4,
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["risk_source"] == "clinical_rule"
    assert body["risk_level"] == "HIGH"


def test_diabetes_risk_returns_provenance_for_model_or_fallback_path():
    response = client.post(
        "/diabetes-risk",
        headers=OPERATOR_HEADERS,
        json={
            "age": 35,
            "gender": "Female",
            "bmi": 22.0,
            "family_history": False,
        },
    )

    assert response.status_code == 200, response.text
    assert response.json()["risk_source"] in {"ml", "heuristic"}


def test_status_reports_unavailable_clinical_backend():
    response = client.get("/status", headers=OPERATOR_HEADERS)

    assert response.status_code == 200, response.text
    body = response.json()
    from api.services.ai_bridge import AIBridge

    if AIBridge.get_instance().dr_classifier.get_backend() == "simulated":
        assert body["ai_engine"].startswith("Degraded")
        assert "UNAVAILABLE" in body["models_loaded"]["Model 2 (DR Classifier)"]
