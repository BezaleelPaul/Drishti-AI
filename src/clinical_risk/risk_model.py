from __future__ import annotations

from typing import List
from src.clinical_risk.schema import (
    DiabetesRiskAssessment,
    DiabetesStatus,
    PatientClinicalProfile,
    RiskLevel,
    ScreeningPathway,
)


class DiabetesRiskModel:
    """
    Upstream Diabetes Risk Assessment Engine (Layer 1 & 2).
    Evaluates clinical and lifestyle parameters before retinal screening.
    Adheres strictly to the principle:
    'AI does not diagnose diabetes from symptoms alone. High-risk patients are
     directed toward laboratory testing (HbA1c/FPG) for physician confirmation.'
    """

    def evaluate(self, profile: PatientClinicalProfile) -> DiabetesRiskAssessment:
        rationale: List[str] = []
        score = 0.0

        # Check for already confirmed diabetes diagnosis or clinical criteria
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

        # Biomarker validation if present
        if profile.hba1c_pct is not None:
            if profile.hba1c_pct >= 6.5:
                rationale.append(f"Diagnostic HbA1c level: {profile.hba1c_pct:.1f}% (>= 6.5% diagnostic of diabetes).")
                return DiabetesRiskAssessment(
                    risk_level=RiskLevel.HIGH,
                    risk_score=95.0,
                    diabetes_status=DiabetesStatus.CONFIRMED_DIABETES,
                    pathway=ScreeningPathway.RETINAL_SCREENING_INDICATED,
                    clinical_rationale=rationale,
                    action_recommendation=(
                        "HbA1c indicates diabetes. Proceed to retinal fundus screening and physician consult."
                    ),
                )
            elif profile.hba1c_pct >= 5.7:
                score += 35.0
                rationale.append(f"Pre-diabetic HbA1c level: {profile.hba1c_pct:.1f}% (5.7% - 6.4%).")

        if profile.fasting_glucose_mg_dl is not None:
            if profile.fasting_glucose_mg_dl >= 126:
                rationale.append(f"Fasting glucose: {profile.fasting_glucose_mg_dl:.0f} mg/dL (>= 126 mg/dL).")
                return DiabetesRiskAssessment(
                    risk_level=RiskLevel.HIGH,
                    risk_score=95.0,
                    diabetes_status=DiabetesStatus.CONFIRMED_DIABETES,
                    pathway=ScreeningPathway.RETINAL_SCREENING_INDICATED,
                    clinical_rationale=rationale,
                    action_recommendation=(
                        "Fasting blood glucose diagnostic of diabetes. Proceed to retinal screening and physician consult."
                    ),
                )
            elif profile.fasting_glucose_mg_dl >= 100:
                score += 25.0
                rationale.append(f"Impaired fasting glucose: {profile.fasting_glucose_mg_dl:.0f} mg/dL.")

        # Age scoring (MDRF/ADA criteria)
        if profile.age >= 50:
            score += 30.0
            rationale.append(f"Age >= 50 years (+30 pts)")
        elif profile.age >= 35:
            score += 20.0
            rationale.append(f"Age 35-49 years (+20 pts)")
        else:
            score += 5.0

        # BMI scoring
        if profile.bmi >= 27.5: # Asian-Indian BMI cutoff for obesity
            score += 25.0
            rationale.append(f"BMI {profile.bmi:.1f} kg/m² >= 27.5 (elevated obesity risk, +25 pts)")
        elif profile.bmi >= 23.0: # Asian-Indian cutoff for overweight
            score += 15.0
            rationale.append(f"BMI {profile.bmi:.1f} kg/m² >= 23.0 (overweight range, +15 pts)")

        # Family History
        if profile.family_history_diabetes:
            score += 20.0
            rationale.append("First-degree family history of diabetes (+20 pts)")

        # Physical Activity
        if profile.physical_activity.lower() == "sedentary":
            score += 15.0
            rationale.append("Sedentary lifestyle (+15 pts)")

        # Classic Symptoms
        if profile.symptoms:
            score += min(len(profile.symptoms) * 5.0, 15.0)
            rationale.append(f"Reported symptoms: {', '.join(profile.symptoms)}")

        score = min(score, 100.0)

        # Pathway determination
        if score >= 60.0:
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
        elif score >= 35.0:
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
