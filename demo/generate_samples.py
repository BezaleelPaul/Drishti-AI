"""
Generates synthetic sample fundus images matching the 4 demo scenarios in Section 24.
"""

import os
import numpy as np
from PIL import Image, ImageFilter


def generate_sample_suite(output_dir: str = "demo/sample_images"):
    os.makedirs(output_dir, exist_ok=True)
    size = (512, 512)
    h, w = size

    # Helper: Base realistic retinal circle
    def create_retinal_base():
        img = np.zeros((h, w, 3), dtype=np.uint8)
        cy, cx = h // 2, w // 2
        r = int(min(h, w) * 0.42)
        y, x = np.ogrid[:h, :w]
        mask = (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2

        # Red-orange retinal hue
        dist_from_center = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
        base_r = np.clip(210 - dist_from_center * 50, 0, 255)
        base_g = np.clip(110 - dist_from_center * 40, 0, 255)
        base_b = np.clip(45 - dist_from_center * 20, 0, 255)

        img[mask, 0] = base_r[mask]
        img[mask, 1] = base_g[mask]
        img[mask, 2] = base_b[mask]

        # Add optic disc (bright yellowish circle on nasal side)
        od_cy, od_cx = cy, cx - int(r * 0.45)
        od_mask = (x - od_cx) ** 2 + (y - od_cy) ** 2 <= (r * 0.16) ** 2
        img[od_mask & mask, 0] = 245
        img[od_mask & mask, 1] = 225
        img[od_mask & mask, 2] = 140

        # Add major vascular arcades
        for angle_deg in [-40, -20, 0, 20, 40, 140, 160, 200, 220]:
            rad = np.deg2rad(angle_deg)
            for d in range(15, int(r * 0.85)):
                vx = int(od_cx + d * np.cos(rad) + 10 * np.sin(d / 20.0))
                vy = int(od_cy + d * np.sin(rad))
                if 0 <= vx < w and 0 <= vy < h and mask[vy, vx]:
                    img[max(0, vy - 2):min(h, vy + 3), max(0, vx - 2):min(w, vx + 3), 0] = 130
                    img[max(0, vy - 2):min(h, vy + 3), max(0, vx - 2):min(w, vx + 3), 1] = 50
                    img[max(0, vy - 2):min(h, vy + 3), max(0, vx - 2):min(w, vx + 3), 2] = 25
        return Image.fromarray(img)

    # 1. Scenario 1: Clean Good image
    img_good = create_retinal_base()
    img_good.save(os.path.join(output_dir, "scenario_1_good.jpg"), quality=95)

    # 2. Scenario 2: Severe Bad image (severe blur + underexposure)
    img_bad_raw = create_retinal_base()
    # Darken heavily and blur heavily
    arr_bad = np.array(img_bad_raw).astype(np.float32) * 0.15
    img_bad = Image.fromarray(arr_bad.astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius=8))
    img_bad.save(os.path.join(output_dir, "scenario_2_bad.jpg"), quality=95)

    # 3. Scenario 3: Borderline image (marginal focus/blur)
    img_borderline = create_retinal_base().filter(ImageFilter.GaussianBlur(radius=2.5))
    arr_bord = np.array(img_borderline).astype(np.float32) * 0.70
    img_borderline = Image.fromarray(arr_bord.astype(np.uint8))
    img_borderline.save(os.path.join(output_dir, "scenario_3_borderline.jpg"), quality=95)

    # 4. Scenario 4: Uncertain / High-Risk image (clear image with subtle lesion features)
    img_uncertain = create_retinal_base()
    # Add scattered micro-hemorrhages
    arr_unc = np.array(img_uncertain)
    np.random.seed(42)
    for _ in range(30):
        rx, ry = np.random.randint(150, 360), np.random.randint(150, 360)
        arr_unc[ry - 3:ry + 4, rx - 3:rx + 4, 0] = 90
        arr_unc[ry - 3:ry + 4, rx - 3:rx + 4, 1] = 20
        arr_unc[ry - 3:ry + 4, rx - 3:rx + 4, 2] = 10
    Image.fromarray(arr_unc).save(os.path.join(output_dir, "scenario_4_uncertain.jpg"), quality=95)

    print(f"Generated 4 demo scenario images in {output_dir}")

if __name__ == "__main__":
    generate_sample_suite()
