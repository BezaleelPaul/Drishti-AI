# mBRSET multimodal DR model (research scaffold)

This module is deliberately separate from the shipped screening pipeline.

## What it does
- Audits a locally downloaded mBRSET release without uploading patient data.
- Builds a patient-grouped manifest from an explicitly mapped metadata CSV.
- Trains an image + clinical-feature fusion model for **DR grade (0–4)**.
- Exports a PyTorch checkpoint and ONNX model for a later LiteRT/TFLite conversion and Flutter integration.

## Important target distinction
The supervised target here is **DR grade**. Clinical measurements are input features to improve DR grading; they are not a second ground-truth target. The existing diabetes-risk assessment remains a separate clinical pathway. mBRSET's diabetic cohort and metadata do not, by themselves, provide a validated label for predicting future diabetes or a standalone clinical risk outcome. Do not relabel diabetes duration, insulin use, or hypertension as a DR outcome.

## Dataset access and privacy
1. Obtain mBRSET through its official PhysioNet access process.
2. Extract it locally; do not commit images, patient-level CSVs, identifiers, or derived PHI to Git.
3. Run the audit:
   `python -m research.mbrset_multimodal.audit_dataset --root /path/to/mbrset --metadata /path/to/metadata.csv`
4. Review the report and explicitly map the actual release's columns. The tool does not assume a schema or guess labels.

## Training
Install the optional deep-learning dependencies, then provide a JSON config with exact column names:
```json
{
  "metadata_csv": "/data/mbrset/metadata.csv",
  "image_root": "/data/mbrset",
  "image_column": "REPLACE_WITH_IMAGE_COLUMN",
  "patient_column": "REPLACE_WITH_PATIENT_ID_COLUMN",
  "grade_column": "REPLACE_WITH_DR_GRADE_COLUMN",
  "clinical_columns": ["REPLACE_WITH_CLINICAL_COLUMN"],
  "image_size": 224,
  "epochs": 15,
  "batch_size": 16,
  "seed": 42,
  "output_dir": "artifacts/mbrset_fusion"
}
```
`python -m research.mbrset_multimodal.train --config config.json`

The trainer fails closed on missing files, invalid grades, duplicate patient leakage, or too few patient groups. It splits by patient, not image. A final untouched patient-level test set is reserved; validation is used for model selection. Report macro-F1, QWK, balanced accuracy and referable-DR sensitivity/specificity. This scaffold does not claim clinical validity.

## Offline deployment status
The repository already uses LiteRT/TFLite in Flutter. The exported ONNX model is **not yet a Flutter artifact**. Conversion must be performed and numerically parity-tested before integration. The two-input model requires both the image tensor and clinical vector. Missing clinical inputs must use an explicitly trained/evaluated missingness strategy or cause the fusion model to abstain; never silently fill missing values with fabricated values.

## Current blocker
No mBRSET files are present in this repository. Therefore the dataset schema, exact metadata mapping, training, metrics, ONNX export, TFLite conversion and Flutter integration cannot honestly be completed or validated until the licensed dataset is downloaded locally.
