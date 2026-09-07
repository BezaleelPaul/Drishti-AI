"""
FHIR R4 DiagnosticReport & Observation Exporter for ABDM (Ayushman Bharat Digital Mission).
Standardized clinical JSON schema for national tele-retinal health interoperability.
"""
from datetime import datetime
from typing import Any, Dict, Optional

def export_abdm_fhir_diagnostic_report(
    patient_data: Dict[str, Any],
    screening_record: Any,
    biomarkers: Dict[str, Any],
    doctor_name: str = "Dr. S. Ramanathan, MD (Ophthal)",
    doctor_action: str = "Routine Annual Rescreening",
) -> Dict[str, Any]:
    """
    Generates an HL7 FHIR R4 compliant DiagnosticReport resource with embedded Observations.
    Conforms to Indian ABDM / Ayushman Bharat Digital Mission tele-ophthalmology guidelines.
    """
    patient_id = patient_data.get("patient_id", "ABHA-0000-0000-0000")
    timestamp = datetime.utcnow().isoformat() + "Z"
    
    dr_pred = getattr(screening_record, "dr_prediction", None)
    if dr_pred:
        grade_num = dr_pred.predicted_grade.value
        grade_label = dr_pred.predicted_grade.label
        confidence = float(dr_pred.confidence)
        referable = grade_num >= 2
    else:
        grade_num = None
        grade_label = "Ungradable / Image Rejected"
        confidence = 0.0
        referable = False

    # SNOMED CT Codes for Diabetic Retinopathy
    snomed_codes = {
        0: {"code": "392010007", "display": "No diabetic retinopathy (disorder)"},
        1: {"code": "312991009", "display": "Mild nonproliferative diabetic retinopathy (disorder)"},
        2: {"code": "312993007", "display": "Moderate nonproliferative diabetic retinopathy (disorder)"},
        3: {"code": "312994001", "display": "Severe nonproliferative diabetic retinopathy (disorder)"},
        4: {"code": "59276001", "display": "Proliferative diabetic retinopathy (disorder)"},
    }

    dr_coding = snomed_codes.get(grade_num, {"code": "82833005", "display": "Retinal disorder (disorder)"})

    fhir_report = {
        "resourceType": "DiagnosticReport",
        "id": f"dr-screening-{patient_id}-{int(datetime.utcnow().timestamp())}",
        "meta": {
            "profile": [
                "https://nrces.in/ndhm/fhir/r4/StructureDefinition/DiagnosticReportRecord"
            ]
        },
        "status": "final",
        "category": [
            {
                "coding": [
                    {
                        "system": "http://terminology.hl7.org/CodeSystem/v2-0074",
                        "code": "RAD",
                        "display": "Radiology / Ophthalmic Photography"
                    }
                ]
            }
        ],
        "code": {
            "coding": [
                {
                    "system": "http://loinc.org",
                    "code": "81219-8",
                    "display": "Diabetic retinopathy study panel"
                }
            ],
            "text": "AI-Assisted Retinal Screening for Diabetic Retinopathy (MathWorks SIH26038)"
        },
        "subject": {
            "reference": f"Patient/{patient_id}",
            "display": f"Patient {patient_id}"
        },
        "effectiveDateTime": timestamp,
        "issued": timestamp,
        "performer": [
            {
                "display": doctor_name
            },
            {
                "display": "Drishti-AI Screening Engine (MathWorks SIH26038)"
            }
        ],
        "conclusion": (
            f"Diabetic Retinopathy Grade: {grade_label}. "
            f"Referable DR: {'Yes' if referable else 'No'}. "
            f"CSME Risk: {biomarkers.get('csme_risk', 'LOW')}. "
            f"Management Order: {doctor_action}."
        ),
        "conclusionCode": [
            {
                "coding": [
                    {
                        "system": "http://snomed.info/sct",
                        "code": dr_coding["code"],
                        "display": dr_coding["display"]
                    }
                ]
            }
        ],
        "contained": [
            {
                "resourceType": "Observation",
                "id": "obs-dr-grade",
                "status": "final",
                "code": {
                    "coding": [{"system": "http://loinc.org", "code": "68820-0", "display": "Diabetic retinopathy severity grade"}]
                },
                "valueCodeableConcept": {
                    "coding": [{"system": "http://snomed.info/sct", "code": dr_coding["code"], "display": dr_coding["display"]}],
                    "text": grade_label
                }
            },
            {
                "resourceType": "Observation",
                "id": "obs-ai-confidence",
                "status": "final",
                "code": {
                    "text": "Model Confidence / Reliability Metric"
                },
                "valueQuantity": {
                    "value": round(confidence * 100, 1),
                    "unit": "%",
                    "system": "http://unitsofmeasure.org",
                    "code": "%"
                }
            },
            {
                "resourceType": "Observation",
                "id": "obs-microaneurysms",
                "status": "final",
                "code": {
                    "text": "Candidate Microaneurysm Count"
                },
                "valueInteger": biomarkers.get("microaneurysm_count", 0)
            },
            {
                "resourceType": "Observation",
                "id": "obs-vessel-density",
                "status": "final",
                "code": {
                    "text": "Retinal Vessel Density Index"
                },
                "valueQuantity": {
                    "value": biomarkers.get("vessel_density_pct", 0.0),
                    "unit": "%",
                    "system": "http://unitsofmeasure.org",
                    "code": "%"
                }
            },
            {
                "resourceType": "Observation",
                "id": "obs-csme-risk",
                "status": "final",
                "code": {
                    "text": "Clinically Significant Macular Edema Risk Level"
                },
                "valueString": biomarkers.get("csme_risk", "LOW")
            }
        ]
    }
    return fhir_report
