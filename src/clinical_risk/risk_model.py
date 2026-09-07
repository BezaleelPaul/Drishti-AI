from __future__ import annotations

import os
from typing import List, Optional
import numpy as np

from src.clinical_risk.schema import (
    DiabetesRiskAssessment,
    DiabetesStatus,
    PatientClinicalProfile,
    RiskLevel,
    ScreeningPathway,
)

try:
    import joblib
    HAS_JOBLIB = True
except ImportError:
    HAS_JOBLIB = False


class DiabetesRiskModel:
    """
    Upstream Diabetes Risk Assessment Engine (Layer 1 & 2).
    Evaluates clinical and lifestyle parameters using a trained Random Forest ML model
    calibrated to population epidemiological surveys, with clinical biomarker checks.
    
    Clinical Guardrail:
    'AI does not diagnose diabetes from symptoms alone. High-risk patients are
     directed toward laboratory testing (HbA1c/FPG) for physician confirmation.'
    """

    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "diabetes_ml_model.joblib"
        )
        self.ml_model = None
        self.feature_cols = []
        self.importances = {}
        self._load_ml_model()

    def _load_ml_model(self):
        if HAS_JOBLIB and os.path.exists(self.model_path):
            try:
                payload = joblib.load(self.model_path)
                self.ml_model = payload["model"]
                self.feature_cols = payload.get("feature_cols", [])
                self.importances = payload.get("importances", {})
            except Exception:
                self.ml_model = None

    def evaluate(self, profile: PatientClinicalProfile) -> DiabetesRiskAssessment:
        rationale: List[str] = []

        # 1. Check for already confirmed diabetes diagnosis
        if profile.known_diabetes_years is not None and profile.known_diabetes_years >= 0:
            rationale.append(f"Confirmed history of diabetes ({profile.known_diabetes_years:.1f} years duration).")
            return DiabetesRiskAssessment(
                risk_level=RiskLevel.HIGH,
                risk_score=100.0,
                diabetes_status=DiabetesStatus.CONFIRMED_DIABETES,
                pathway=ScreeningPathway.RETINAL_SCREENING_INDICATED,
                clinical_rationale=rationale,
                action_recommendation=(
                    "Proceed immediately to AI-assisted retinal screening for diabetic retinopathy triage."
                ),
            )

        # 2. Laboratory Biomarker Verification (Physician Diagnostic Criteria)
        if profile.hba1c_pct is not None and profile.hba1c_pct >= 6.5:
            rationale.append(f"Diagnostic HbA1c level: {profile.hba1c_pct:.1f}% (>= 6.5% diagnostic of diabetes).")
            return DiabetesRiskAssessment(
                risk_level=RiskLevel.HIGH,
                risk_score=98.0,
                diabetes_status=DiabetesStatus.CONFIRMED_DIABETES,
                pathway=ScreeningPathway.RETINAL_SCREENING_INDICATED,
                clinical_rationale=rationale,
                action_recommendation=(
                    "HbA1c indicates diabetes. Proceed to retinal fundus screening and physician consult."
                ),
            )

        if profile.fasting_glucose_mg_dl is not None and profile.fasting_glucose_mg_dl >= 126.0:
            rationale.append(f"Fasting glucose: {profile.fasting_glucose_mg_dl:.0f} mg/dL (>= 126 mg/dL).")
            return DiabetesRiskAssessment(
                risk_level=RiskLevel.HIGH,
                risk_score=98.0,
                diabetes_status=DiabetesStatus.CONFIRMED_DIABETES,
                pathway=ScreeningPathway.RETINAL_SCREENING_INDICATED,
                clinical_rationale=rationale,
                action_recommendation=(
                    "Fasting blood glucose diagnostic of diabetes. Proceed to retinal screening and physician consult."
                ),
            )

        # 3. Machine Learning Risk Prediction (Random Forest)
        is_sedentary = 1 if profile.physical_activity.lower() == "sedentary" else 0
        symptom_cnt = len(profile.symptoms)
        if "None" in profile.symptoms:
            symptom_cnt = max(0, symptom_cnt - 1)

        if self.ml_model is not None:
            import pandas as pd
            features = pd.DataFrame([[
                profile.age,
                profile.bmi,
                1 if profile.family_history_diabetes else 0,
                is_sedentary,
                symptom_cnt,
            ]], columns=self.feature_cols)

            # Get calibrated probability of diabetes risk from ML model
            ml_prob = float(self.ml_model.predict_proba(features)[0, 1])
            score = round(ml_prob * 100.0, 1)
            rationale.append(f"Random Forest ML risk probability: {ml_prob:.1%}")
        else:
            # Fallback heuristic calculation if model file not available
            score = 0.0
            if profile.age >= 50: score += 28
            elif profile.age >= 35: score += 18
            if profile.bmi >= 27.5: score += 25
            elif profile.bmi >= 23.0: score += 15
            if profile.family_history_diabetes: score += 20
            if is_sedentary: score += 15
            score += min(symptom_cnt * 6.0, 18.0)
            score = min(score, 100.0)

        # Explain top patient contributors
        if profile.age >= 45:
            rationale.append(f"Age {profile.age} (elevated age-related vulnerability)")
        if profile.bmi >= 25.0:
            rationale.append(f"BMI {profile.bmi:.1f} kg/m² (metabolic adiposity factor)")
        if profile.family_history_diabetes:
            rationale.append("Genetic/family predisposition reported")
        if symptom_cnt > 0:
            rationale.append(f"{symptom_cnt} symptom(s) identified ({', '.join(profile.symptoms)})")

        # Biomarker adjustments if in pre-diabetic ranges
        if profile.hba1c_pct is not None and profile.hba1c_pct >= 5.7:
            score = max(score, 65.0)
            rationale.append(f"Impaired HbA1c ({profile.hba1c_pct:.1f}%) elevated risk to high tier.")
        elif profile.fasting_glucose_mg_dl is not None and profile.fasting_glucose_mg_dl >= 100.0:
            score = max(score, 60.0)
            rationale.append(f"Impaired fasting glucose ({profile.fasting_glucose_mg_dl:.0f} mg/dL).")

        # Clinical Triage Boundaries
        if score >= 55.0:
            return DiabetesRiskAssessment(
                risk_level=RiskLevel.HIGH,
                risk_score=score,
                diabetes_status=DiabetesStatus.UNKNOWN,
                pathway=ScreeningPathway.CLINICAL_TESTING_REQUIRED,
                clinical_rationale=rationale,
                action_recommendation=(
                    "Elevated diabetes risk. Recommend formal clinical laboratory testing "
                    "(Fasting Plasma Glucose and HbA1c) for physician diagnosis. "
                    "If confirmed, patient must enroll in annual retinal screening."
                ),
            )
        elif score >= 30.0:
            return DiabetesRiskAssessment(
                risk_level=RiskLevel.MODERATE,
                risk_score=score,
                diabetes_status=DiabetesStatus.UNKNOWN,
                pathway=ScreeningPathway.CLINICAL_TESTING_REQUIRED,
                clinical_rationale=rationale,
                action_recommendation=(
                    "Moderate diabetes risk. Recommend routine screening glucose check "
                    "and lifestyle counseling at primary healthcare centre."
                ),
            )
        else:
            return DiabetesRiskAssessment(
                risk_level=RiskLevel.LOW,
                risk_score=score,
                diabetes_status=DiabetesStatus.NO_DIABETES,
                pathway=ScreeningPathway.LIFESTYLE_PREVENTION,
                clinical_rationale=rationale,
                action_recommendation=(
                    "Low risk. Encourage healthy diet, active lifestyle, and routine re-evaluation every 3 years."
                ),
            )
