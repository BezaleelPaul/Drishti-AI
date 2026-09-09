from __future__ import annotations

import json
from datetime import datetime
import uuid
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query

from api.database import get_connection
from api.schemas import PatientCreate, PatientListResponse, PatientResponse

router = APIRouter(prefix="/patients", tags=["Patients"])


@router.post("", response_model=PatientResponse, status_code=201)
def register_patient(payload: PatientCreate):
    conn = get_connection()
    cursor = conn.cursor()

    patient_id = payload.patient_id or f"PT-2026-{uuid.uuid4().hex[:4].upper()}"
    now = datetime.utcnow().isoformat() + "Z"

    # Check for duplicate
    cursor.execute("SELECT patient_id FROM patients WHERE patient_id = ?", (patient_id,))
    if cursor.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail=f"Patient ID {patient_id} already registered.")

    cursor.execute("""
    INSERT INTO patients (
        patient_id, abha_id, name, age, gender, phone, village, screening_centre,
        known_diabetes, diabetes_duration_years, hba1c, fasting_glucose, blood_pressure,
        bmi, family_history, physical_activity, symptoms, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        patient_id,
        payload.abha_id,
        payload.name,
        payload.age,
        payload.gender,
        payload.phone,
        payload.village,
        payload.screening_centre,
        payload.known_diabetes,
        payload.diabetes_duration_years,
        payload.hba1c,
        payload.fasting_glucose,
        payload.blood_pressure,
        payload.bmi,
        1 if payload.family_history else 0,
        payload.physical_activity,
        json.dumps(payload.symptoms),
        now,
    ))
    conn.commit()
    conn.close()

    return PatientResponse(
        patient_id=patient_id,
        name=payload.name,
        age=payload.age,
        gender=payload.gender,
        phone=payload.phone,
        abha_id=payload.abha_id,
        village=payload.village,
        screening_centre=payload.screening_centre,
        known_diabetes=payload.known_diabetes,
        diabetes_duration_years=payload.diabetes_duration_years,
        hba1c=payload.hba1c,
        fasting_glucose=payload.fasting_glucose,
        blood_pressure=payload.blood_pressure,
        bmi=payload.bmi,
        family_history=payload.family_history,
        physical_activity=payload.physical_activity,
        symptoms=payload.symptoms,
        created_at=now,
    )


@router.get("", response_model=PatientListResponse)
def list_patients(search: Optional[str] = Query(None, description="Search by name, ID, or ABHA")):
    conn = get_connection()
    cursor = conn.cursor()

    if search:
        pattern = f"%{search}%"
        cursor.execute("""
        SELECT * FROM patients
        WHERE name LIKE ? OR patient_id LIKE ? OR abha_id LIKE ? OR phone LIKE ?
        ORDER BY created_at DESC
        """, (pattern, pattern, pattern, pattern))
    else:
        cursor.execute("SELECT * FROM patients ORDER BY created_at DESC")

    rows = cursor.fetchall()
    patients = []
    for r in rows:
        patients.append(PatientResponse(
            patient_id=r["patient_id"],
            name=r["name"],
            age=r["age"],
            gender=r["gender"],
            phone=r["phone"],
            abha_id=r["abha_id"],
            village=r["village"],
            screening_centre=r["screening_centre"],
            known_diabetes=r["known_diabetes"],
            diabetes_duration_years=r["diabetes_duration_years"],
            hba1c=r["hba1c"],
            fasting_glucose=r["fasting_glucose"],
            blood_pressure=r["blood_pressure"],
            bmi=r["bmi"],
            family_history=bool(r["family_history"]),
            physical_activity=r["physical_activity"],
            symptoms=json.loads(r["symptoms"] or "[]"),
            created_at=r["created_at"],
        ))
    conn.close()

    return PatientListResponse(total=len(patients), patients=patients)


@router.get("/{patient_id}", response_model=PatientResponse)
def get_patient(patient_id: str):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM patients WHERE patient_id = ?", (patient_id,))
    r = cursor.fetchone()
    conn.close()

    if not r:
        raise HTTPException(status_code=404, detail=f"Patient {patient_id} not found.")

    return PatientResponse(
        patient_id=r["patient_id"],
        name=r["name"],
        age=r["age"],
        gender=r["gender"],
        phone=r["phone"],
        abha_id=r["abha_id"],
        village=r["village"],
        screening_centre=r["screening_centre"],
        known_diabetes=r["known_diabetes"],
        diabetes_duration_years=r["diabetes_duration_years"],
        hba1c=r["hba1c"],
        fasting_glucose=r["fasting_glucose"],
        blood_pressure=r["blood_pressure"],
        bmi=r["bmi"],
        family_history=bool(r["family_history"]),
        physical_activity=r["physical_activity"],
        symptoms=json.loads(r["symptoms"] or "[]"),
        created_at=r["created_at"],
    )
