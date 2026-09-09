from __future__ import annotations

from fastapi import APIRouter
from api.schemas import DiabetesRiskRequest, DiabetesRiskResponse
from api.services.ai_bridge import AIBridge

router = APIRouter(prefix="/diabetes-risk", tags=["Diabetes Risk Screening"])


@router.post("", response_model=DiabetesRiskResponse)
def evaluate_diabetes_risk(payload: DiabetesRiskRequest):
    """
    Upstream Clinical Risk Assessment (Layer 1 & 2).
    Distinguishes risk prediction from definitive medical diagnosis.
    Recommends laboratory testing and retinal screening when elevated risk is identified.
    """
    bridge = AIBridge.get_instance()
    result = bridge.evaluate_diabetes_risk(payload.dict())
    return DiabetesRiskResponse(**result)
