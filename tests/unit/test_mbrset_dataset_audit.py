from pathlib import Path

import pandas as pd

from research.mbrset_multimodal.audit_dataset import audit


def test_audit_reports_aggregate_fields_without_patient_rows(tmp_path: Path):
    root = tmp_path / "images"
    root.mkdir()
    (root / "eye_001.jpg").write_bytes(b"not-a-real-image")
    metadata = tmp_path / "metadata.csv"
    pd.DataFrame({
        "patient_id": ["p1", "p2"],
        "image_path": ["eye_001.jpg", "missing.jpg"],
        "dr_grade": [0, 2],
        "age": [51, None],
        "hypertension": [True, False],
    }).to_csv(metadata, index=False)

    report = audit(root, metadata)

    assert report["rows"] == 2
    assert report["image_file_count"] == 1
    assert "patient_id" in report["candidate_patient_id_columns"]
    assert "image_path" in report["candidate_image_columns"]
    assert report["candidate_grade_distributions"]["dr_grade"] == {"0": 1, "2": 1}
    assert "patient_id" not in report  # no patient-level identifiers emitted
