# On-device model artifacts

## Shipped: `dr_efficientnet_b0_fp32.tflite` (15.3 MB)

Converted from `final_model.keras` (33.4 MB) via
`scripts/convert/convert_to_tflite.py` and **parity-gated** by
`validate_tflite_quantized.py`:

| Artifact | Size | Top-1 agreement vs keras | Verdict |
|---|---|---|---|
| fp32 | 15.3 MB | **100%** (6/6 clinical corpus) | **SHIPPED** |
| fp16 | 4.4 MB | 83.3% (max prob drift 0.29) | REJECTED by gate |
| int8 | — | pending real calibration corpus | planned |

Evidence: `results/tflite_parity_fp32_clinical.json`,
`results/tflite_parity_fp32_scenarios.json`,
`results/tflite_parity_fp16_clinical.json`.

## int8 upgrade path (post-hackathon size optimization)

1. Download a stratified APTOS/EyePACS calibration corpus (400 images, all
   5 grades — never the test split).
2. `python scripts/convert/convert_to_tflite.py --source final_model.keras --rep-images-dir <dir>`
3. `python validate_tflite_quantized.py --tflite scripts/convert/out/dr_efficientnet_b0_int8.tflite --images-dir <stratified set>`
4. On PASS: copy here, update `DrClassifierDart.defaultModelAsset` and the
   pubspec asset line together.

Until then the fp32 artifact IS the deployment truth: raw 0–255 float32
NHWC input, softmax 5-vector out, confidence gate 0.60/0.15 downstream.
