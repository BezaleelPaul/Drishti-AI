"""
Lightweight SQLite persistence layer for Netra-AI.
Stores patients, screening records, and doctor review actions.
Fully offline-first and portable across platforms.
"""
from __future__ import annotations

import sqlite3
import json
import os
from datetime import datetime
from typing import Any, Dict, List, Optional

_DB_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
os.makedirs(_DB_DIR, exist_ok=True)
DB_PATH = os.path.join(_DB_DIR, "screening_platform.db")


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Initializes schema and pre-populates demo rural patients if empty."""
    conn = get_connection()
    cursor = conn.cursor()

    # 1. Patients Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS patients (
        patient_id TEXT PRIMARY KEY,
        abha_id TEXT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        phone TEXT,
        village TEXT,
        screening_centre TEXT,
        known_diabetes TEXT DEFAULT 'Unknown',
        diabetes_duration_years REAL,
        hba1c REAL,
        fasting_glucose REAL,
        blood_pressure TEXT,
        bmi REAL,
        family_history BOOLEAN DEFAULT 0,
        physical_activity TEXT DEFAULT 'Moderate',
        symptoms TEXT DEFAULT '[]',
        created_at TEXT NOT NULL
    )
    """)

    # 2. Retinal Screenings Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS screenings (
        screening_id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        eye_side TEXT NOT NULL,          -- 'Right' or 'Left'
        camera_profile TEXT DEFAULT 'Generic Fundus Camera',
        quality_grade TEXT NOT NULL,    -- 'GOOD', 'BORDERLINE', 'BAD'
        quality_score REAL,
        rejection_reasons TEXT,         -- JSON array
        suspected_clinical_cause TEXT,
        recapture_instructions TEXT,
        dr_grade_num INTEGER,           -- 0 to 4
        dr_grade_label TEXT,
        dr_confidence REAL,
        is_referable BOOLEAN DEFAULT 0,
        requires_human_review BOOLEAN DEFAULT 0,
        human_review_type TEXT,
        human_review_reason TEXT,
        original_image_path TEXT,
        gradcam_overlay_path TEXT,
        target_layer TEXT,
        action_recommendation TEXT,
        screening_status TEXT DEFAULT 'Completed',
        created_at TEXT NOT NULL,
        FOREIGN KEY(patient_id) REFERENCES patients(patient_id)
    )
    """)

    # 3. Doctor Review Queue & Decisions Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS doctor_reviews (
        review_id TEXT PRIMARY KEY,
        screening_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'CONFIRMED', 'OVERRIDDEN', 'REFERRED', 'RECAPTURE_REQUESTED'
        doctor_name TEXT,
        doctor_decision TEXT,
        doctor_grade_override INTEGER,
        clinical_notes TEXT,
        referral_urgency TEXT,
        follow_up_days INTEGER,
        created_at TEXT NOT NULL,
        reviewed_at TEXT,
        FOREIGN KEY(screening_id) REFERENCES screenings(screening_id),
        FOREIGN KEY(patient_id) REFERENCES patients(patient_id)
    )
    """)

    # Check if demo seed data exists
    cursor.execute("SELECT COUNT(*) as count FROM patients")
    if cursor.fetchone()["count"] == 0:
        _seed_demo_data(cursor)

    conn.commit()
    conn.close()


def _seed_demo_data(cursor: sqlite3.Cursor):
    now = datetime.utcnow().isoformat() + "Z"
    sample_patients = [
        (
            "PT-2026-101",
            "91-4521-8890-3321",
            "Ramesh Kumar",
            54,
            "Male",
            "+91 98451 22340",
            "Shivaji Nagar, PHC Bhor",
            "Bhor Rural Health Sub-Centre",
            "Yes",
            6.0,
            8.2,
            165.0,
            "138/86",
            28.4,
            1,
            "Sedentary",
            json.dumps(["Blurry vision", "Mild fatigue"]),
            now,
        ),
        (
            "PT-2026-102",
            "91-7712-4402-9981",
            "Sunita Devi",
            48,
            "Female",
            "+91 94210 55123",
            "Khed Village, PHC Khed",
            "Khed Community Health Centre",
            "No",
            0.0,
            6.2,
            110.0,
            "122/80",
            25.1,
            1,
            "Moderate",
            json.dumps(["Mild fatigue"]),
            now,
        ),
        (
            "PT-2026-103",
            "91-2309-1144-6677",
            "Anand Patil",
            62,
            "Male",
            "+91 97633 11890",
            "Wadgaon, Mobile Van #2",
            "Western Ghats Screening Van",
            "Yes",
            12.0,
            9.4,
            210.0,
            "145/92",
            30.2,
            1,
            "Sedentary",
            json.dumps(["Blurry vision", "Frequent urination", "Dark spots in vision"]),
            now,
        )
    ]
    cursor.executemany("""
    INSERT INTO patients (
        patient_id, abha_id, name, age, gender, phone, village, screening_centre,
        known_diabetes, diabetes_duration_years, hba1c, fasting_glucose, blood_pressure,
        bmi, family_history, physical_activity, symptoms, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, sample_patients)


init_db()
