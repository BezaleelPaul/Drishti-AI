import unittest
import numpy as np
from PIL import Image

from src.pipeline.schema import QualityGrade, QualityReason
from src.quality.checker import ImageQualityChecker, QualityThresholds


def create_synthetic_fundus_image(
    size=(256, 256),
    blur_level: float = 0.0,
    brightness_shift: float = 0.0,
    is_non_fundus: bool = False,
) -> np.ndarray:
    """Generates a synthetic circular retinal image for testing."""
    h, w = size
    img = np.zeros((h, w, 3), dtype=np.uint8)

    if is_non_fundus:
        # Gray checkerboard / random blue noise
        img[:, :, 2] = np.random.randint(150, 255, (h, w), dtype=np.uint8)
        img[:, :, 0] = np.random.randint(20, 50, (h, w), dtype=np.uint8)
        return img

    # Circular mask for fundus
    cy, cx = h // 2, w // 2
    r = int(min(h, w) * 0.42)
    y, x = np.ogrid[:h, :w]
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    circle_mask = dist <= r

    # Radial shading from macula to periphery for natural retinal contrast
    dist_norm = dist / (r + 1e-5)
    base_r = np.clip(210 - dist_norm * 50 + brightness_shift, 0, 255)
    base_g = np.clip(110 - dist_norm * 40 + brightness_shift * 0.6, 0, 255)
    base_b = np.clip(45 - dist_norm * 20 + brightness_shift * 0.3, 0, 255)

    img[circle_mask, 0] = base_r[circle_mask].astype(np.uint8)
    img[circle_mask, 1] = base_g[circle_mask].astype(np.uint8)
    img[circle_mask, 2] = base_b[circle_mask].astype(np.uint8)

    # Optic disc (nasal bright spot)
    od_cy, od_cx = cy, cx - int(r * 0.45)
    od_mask = (x - od_cx) ** 2 + (y - od_cy) ** 2 <= (r * 0.18) ** 2
    img[od_mask & circle_mask, 0] = 245
    img[od_mask & circle_mask, 1] = 220
    img[od_mask & circle_mask, 2] = 130

    # Add retinal vessel-like features (sharp high frequency lines)
    if blur_level == 0.0:
        for angle_deg in [-30, 0, 30, 150, 180, 210]:
            rad = np.deg2rad(angle_deg)
            for d in range(10, int(r * 0.8)):
                vx = int(od_cx + d * np.cos(rad))
                vy = int(od_cy + d * np.sin(rad))
                if 0 <= vx < w and 0 <= vy < h and circle_mask[vy, vx]:
                    img[max(0, vy - 1):min(h, vy + 2), max(0, vx - 1):min(w, vx + 2), 0] = 120
                    img[max(0, vy - 1):min(h, vy + 2), max(0, vx - 1):min(w, vx + 2), 1] = 45
                    img[max(0, vy - 1):min(h, vy + 2), max(0, vx - 1):min(w, vx + 2), 2] = 20

    return img


class TestImageQualityChecker(unittest.TestCase):

    def setUp(self):
        self.checker = ImageQualityChecker()

    def test_sharp_fundus_grades_good(self):
        img = create_synthetic_fundus_image()
        result = self.checker.assess_image(img)
        self.assertIn(result.grade, (QualityGrade.GOOD, QualityGrade.BORDERLINE))
        self.assertGreater(result.metrics.sharpness_score, 0.0)

    def test_severely_underexposed_image_grades_bad(self):
        img = create_synthetic_fundus_image(brightness_shift=-180.0)
        result = self.checker.assess_image(img)
        self.assertEqual(result.grade, QualityGrade.BAD)
        self.assertIn(QualityReason.INADEQUATE_ILLUMINATION, result.reasons)

    def test_non_fundus_image_grades_bad(self):
        img = create_synthetic_fundus_image(is_non_fundus=True)
        result = self.checker.assess_image(img)
        self.assertEqual(result.grade, QualityGrade.BAD)
        self.assertIn(QualityReason.NON_FUNDUS_OR_CORRUPT, result.reasons)

    def test_strict_mode_increases_scrutiny(self):
        img = create_synthetic_fundus_image(brightness_shift=-40.0)
        res_normal = self.checker.assess_image(img, strict_mode=False)
        res_strict = self.checker.assess_image(img, strict_mode=True)
        # Strict mode should be equal or stricter
        severity_rank = {QualityGrade.GOOD: 1, QualityGrade.BORDERLINE: 2, QualityGrade.BAD: 3}
        self.assertGreaterEqual(severity_rank[res_strict.grade], severity_rank[res_normal.grade])


if __name__ == "__main__":
    unittest.main()
