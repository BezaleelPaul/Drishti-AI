"""
Builds a curated, categorized Test Pack for team verification.
Includes real-world clinical fundus captures, quality failures,
adversarial non-fundus files, and Section 24 hackathon scenarios.
"""

import os
import shutil

import numpy as np
from PIL import Image, ImageFilter


def build_curated_test_pack():
    base_dir = "test_samples"
    dirs = [
        os.path.join(base_dir, "01_real_clinical_fundus"),
        os.path.join(base_dir, "02_quality_failures_and_edge_cases"),
        os.path.join(base_dir, "03_adversarial_non_fundus"),
        os.path.join(base_dir, "04_section24_demo_scenarios"),
    ]
    for d in dirs:
        os.makedirs(d, exist_ok=True)

    print("Building curated test samples for team audit...")

    # 1. Real Clinical Fundus Images (from Berens Lab toolbox)
    src_real_1 = os.path.join("external", "fundus_image_toolbox", "0_example_usage", "imgs", "fundus1.jpg")
    src_real_2 = os.path.join("external", "fundus_image_toolbox", "0_example_usage", "imgs", "fundus2.jpg")
    src_real_3 = os.path.join("external", "fundus_image_toolbox", "0_example_usage", "imgs", "drimdb_example.jpg")

    if os.path.exists(src_real_1):
        shutil.copy(src_real_1, os.path.join(dirs[0], "real_clinical_fundus_patient1.jpg"))
    if os.path.exists(src_real_2):
        shutil.copy(src_real_2, os.path.join(dirs[0], "real_clinical_fundus_patient2.jpg"))
    if os.path.exists(src_real_3):
        shutil.copy(src_real_3, os.path.join(dirs[0], "real_clinical_drimdb_sample.jpg"))

    # 2. Section 24 Demo Scenarios
    curated_src = os.path.join("test_samples", "curated")
    if os.path.exists(curated_src):
        for f in os.listdir(curated_src):
            if f.endswith((".jpg", ".png")):
                shutil.copy(os.path.join(curated_src, f), os.path.join(dirs[3], f))

    # 3. Quality Failures & Edge Cases
    # Severe glare / overexposure
    glare_img = np.ones((512, 512, 3), dtype=np.uint8) * 240
    glare_img[100:400, 100:400] = 255
    Image.fromarray(glare_img).save(os.path.join(dirs[1], "overexposed_glare_capture.jpg"))

    # Severe underexposure / pitch dark
    dark_img = np.zeros((512, 512, 3), dtype=np.uint8)
    dark_img[50:450, 50:450] = 12
    Image.fromarray(dark_img).save(os.path.join(dirs[1], "severely_underexposed_dark.jpg"))

    # Extreme motion blur
    if os.path.exists(src_real_1):
        real_im = Image.open(src_real_1).convert("RGB")
        heavy_blur = real_im.filter(ImageFilter.GaussianBlur(radius=12))
        heavy_blur.save(os.path.join(dirs[1], "real_fundus_with_extreme_motion_blur.jpg"))

    # 4. Adversarial Non-Fundus Images
    # Blue / cold non-retinal pattern (e.g. chest X-ray simulation or random photo)
    non_fundus_cold = np.zeros((512, 512, 3), dtype=np.uint8)
    non_fundus_cold[:, :, 2] = 200 # Heavy blue channel
    non_fundus_cold[:, :, 1] = 100
    non_fundus_cold[:, :, 0] = 40
    Image.fromarray(non_fundus_cold).save(os.path.join(dirs[2], "adversarial_non_fundus_blue_profile.jpg"))

    # Uniform grey wall photo
    grey_wall = np.ones((512, 512, 3), dtype=np.uint8) * 128
    Image.fromarray(grey_wall).save(os.path.join(dirs[2], "adversarial_flat_grey_surface.jpg"))

    # 5. Write Test Guide
    guide_content = """# 🧪 Team Verification Test Guide

This folder contains pre-packaged test cases to verify credibility across your team.

---

## Folder 1: `01_real_clinical_fundus/`
- **What it is:** Real-world retinal fundus photographs from hospital screenings (Berens Lab / DRIMDB).
- **Who tests it:** **Bezaleel & Akshay**
- **Expected Result:**
  - Image Quality Gate (Model 1): **`GOOD` (Reliable Original Image)**
  - Model 2: Outputs 5-class DR probability vector and Grad-CAM attention overlay.

---

## Folder 2: `02_quality_failures_and_edge_cases/`
- **What it is:** Challenging field conditions (severe camera glare, extreme underexposure, heavy motion blur).
- **Who tests it:** **Madhu**
- **Expected Result:**
  - Image Quality Gate: **`BAD`**
  - DR Prediction: **`Not generated`** (Strictly blocked!).
  - Action: Prompt to recapture image with reason code (`Severe blur`, `Inadequate illumination`, or `Severe glare`).

---

## Folder 3: `03_adversarial_non_fundus/`
- **What it is:** Adversarial non-retinal inputs (blue photos, flat surfaces, or random images).
- **Who tests it:** **Madhu**
- **Expected Result:**
  - Color profile & retinal mask verification halts the image: **`BAD`**.
  - Reason: `Non-fundus or corrupt image file`.
  - **Zero leakage** into disease grading.

---

## Folder 4: `04_section24_demo_scenarios/`
- **What it is:** The official 4 demo cases from Section 24 of the Approved Specification.
- **Who tests it:** **Adithya & Team**
  1. `scenario_1_good.jpg`: Clean capture $\\rightarrow$ Normal/Graded $\\rightarrow$ Grad-CAM.
  2. `scenario_2_bad.jpg`: Fails quality $\\rightarrow$ immediate recapture request.
  3. `scenario_3_borderline.jpg`: Marginal quality $\\rightarrow$ enters reassessment.
  4. `scenario_4_uncertain.jpg`: Graded case $\\rightarrow$ triggers **mandatory human review** due to low margin or high risk.

---

## How to Test in the Browser:
1. Start the API with `make run`.
2. Open the Flutter app at **`http://localhost:8000/app`**.
3. Use the screening flow with any image from these folders and observe the decision flow.
"""

    with open(os.path.join(base_dir, "TEST_GUIDE.md"), "w", encoding="utf-8") as f:
        f.write(guide_content)

    print("Test pack successfully assembled in test_samples/")


if __name__ == "__main__":
    build_curated_test_pack()
