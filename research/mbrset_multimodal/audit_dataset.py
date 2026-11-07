"""Audit a local mBRSET release without exposing patient-level data."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd


def audit(root: Path, metadata: Path) -> dict:
    if not root.exists() or not metadata.is_file():
        raise FileNotFoundError("Dataset root and metadata CSV must exist locally.")
    frame = pd.read_csv(metadata)
    image_files = [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png"}]
    columns = list(frame.columns)
    lower = {c: c.lower().replace("-", "_").replace(" ", "_") for c in columns}

    def candidates(tokens: tuple[str, ...]) -> list[str]:
        return [c for c, normalized in lower.items() if any(t in normalized for t in tokens)]

    report = {
        "metadata_file": metadata.name,
        "rows": int(len(frame)),
        "columns": columns,
        "image_file_count": len(image_files),
        "candidate_patient_id_columns": candidates(("patient", "subject", "participant", "person", "id")),
        "candidate_image_columns": candidates(("image", "file", "path", "filename", "photo")),
        "candidate_dr_grade_columns": candidates(("dr_grade", "retinopathy", "diabetic_retinopathy", "severity", "grade")),
        "candidate_clinical_columns": candidates(("age", "sex", "gender", "diabetes", "insulin", "hypertension", "hba1c", "glucose", "bmi")),
        "missing_values_by_column": {str(c): int(frame[c].isna().sum()) for c in columns},
        "duplicate_rows": int(frame.duplicated().sum()),
    }
    # Aggregate label counts only for likely DR-grade fields; never emit patient rows.
    report["candidate_grade_distributions"] = {}
    for col in report["candidate_dr_grade_columns"]:
        counts = frame[col].astype("string").value_counts(dropna=False).head(20)
        report["candidate_grade_distributions"][str(col)] = {str(k): int(v) for k, v in counts.items()}
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path("mbrset_audit.json"))
    args = parser.parse_args()
    report = audit(args.root, args.metadata)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k not in {"columns", "missing_values_by_column", "candidate_grade_distributions"}}, indent=2))
    print(f"Full aggregate audit written to {args.out}")


if __name__ == "__main__":
    main()
