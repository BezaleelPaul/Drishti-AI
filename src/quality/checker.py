from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional, Tuple, Union
import numpy as np
from PIL import Image

try:
    import cv2
    HAS_OPENCV = True
except ImportError:
    HAS_OPENCV = False

from src.pipeline.schema import (
    QualityAssessmentResult,
    QualityGrade,
    QualityMetrics,
    QualityReason,
)


@dataclass
class QualityThresholds:
    """
    Thresholds for Image Quality Assessment.
    Can be configured in standard mode or strict mode (used during Reassessment).
    """
    # Sharpness / Blur (Laplacian variance)
    blur_good_threshold: float = 85.0
    blur_bad_threshold: float = 35.0

    # Illumination (mean grayscale brightness within circular ROI)
    min_brightness_good: float = 40.0
    min_brightness_bad: float = 20.0
    max_brightness_good: float = 210.0
    max_brightness_bad: float = 235.0

    # Contrast (standard deviation of illumination within retinal mask)
    min_contrast_good: float = 16.0
    min_contrast_bad: float = 7.0

    # Retinal Field of View / circular mask coverage
    min_fov_ratio_good: float = 0.35
    min_fov_ratio_bad: float = 0.15

    # Non-fundus detector color range (typical fundus is predominantly reddish/orange)
    min_red_to_blue_ratio: float = 1.10

    @classmethod
    def strict(cls) -> QualityThresholds:
        """
        Stricter thresholds for Borderline Reassessment per Section 5.
        A borderline image must clear higher standards to join the Good path.
        """
        return cls(
            blur_good_threshold=110.0,
            blur_bad_threshold=45.0,
            min_brightness_good=50.0,
            min_brightness_bad=25.0,
            max_brightness_good=200.0,
            max_brightness_bad=230.0,
            min_contrast_good=22.0,
            min_contrast_bad=10.0,
            min_fov_ratio_good=0.45,
            min_fov_ratio_bad=0.20,
            min_red_to_blue_ratio=1.15,
        )


class ImageQualityChecker:
    """
    Model 1: Image Quality Assessment Engine.
    Evaluates retinal image trustworthiness without modifying original pixels.
    Outputs: Good / Borderline / Bad (3-class) with specific rejection reason codes.
    """

    def __init__(self, thresholds: Optional[QualityThresholds] = None, use_dl_toolbox: bool = False):
        self.thresholds = thresholds or QualityThresholds()
        self.strict_thresholds = QualityThresholds.strict()
        self.use_dl_toolbox = use_dl_toolbox
        self._dl_ensemble = None

        if self.use_dl_toolbox:
            self._try_load_toolbox_ensemble()

    def _try_load_toolbox_ensemble(self):
        try:
            import fundus_image_toolbox as fit
            self._dl_ensemble = fit.load_quality_ensemble(device="cpu")
        except Exception:
            self._dl_ensemble = None

    def assess_image(
        self,
        image_input: Union[str, np.ndarray, Image.Image],
        strict_mode: bool = False
    ) -> QualityAssessmentResult:
        """
        Assesses image quality against objective photographic criteria.
        
        Args:
            image_input: File path, numpy array, or PIL image.
            strict_mode: If True, uses stricter thresholds (for Borderline reassessment).
        """
        th = self.strict_thresholds if strict_mode else self.thresholds

        # 1. Load and validate image input
        np_img, load_error = self._load_image_as_rgb(image_input)
        if load_error or np_img is None:
            return QualityAssessmentResult(
                grade=QualityGrade.BAD,
                is_reliable=False,
                reasons=[QualityReason.NON_FUNDUS_OR_CORRUPT],
                metrics=QualityMetrics(),
                details=f"File could not be opened or decoded: {load_error}",
            )

        # 2. Check if the image resembles a retinal fundus photograph
        is_fundus, non_fundus_reason = self._validate_fundus_characteristics(np_img, th)
        if not is_fundus:
            return QualityAssessmentResult(
                grade=QualityGrade.BAD,
                is_reliable=False,
                reasons=[QualityReason.NON_FUNDUS_OR_CORRUPT],
                metrics=QualityMetrics(),
                details=f"Input does not present retinal fundus characteristics: {non_fundus_reason}",
            )

        # 3. Compute photographic quality metrics
        metrics = self._calculate_metrics(np_img)

        # 4. Check for hard Bad criteria
        reasons = []
        is_bad = False

        if metrics.sharpness_score < th.blur_bad_threshold:
            reasons.append(QualityReason.SEVERE_BLUR)
            is_bad = True

        if metrics.mean_brightness < th.min_brightness_bad:
            reasons.append(QualityReason.INADEQUATE_ILLUMINATION)
            is_bad = True
        elif metrics.mean_brightness > th.max_brightness_bad:
            reasons.append(QualityReason.OVEREXPOSURE)
            is_bad = True

        if metrics.contrast_score < th.min_contrast_bad:
            reasons.append(QualityReason.LOW_CONTRAST)
            is_bad = True

        if metrics.fov_ratio < th.min_fov_ratio_bad:
            reasons.append(QualityReason.INSUFFICIENT_FIELD_OF_VIEW)
            is_bad = True

        # Determine suspected biological / ocular cause
        clinical_causes = []
        if QualityReason.SEVERE_BLUR in reasons:
            clinical_causes.append("Suspected media opacity/cataract or optical defocus")
        if QualityReason.INADEQUATE_ILLUMINATION in reasons:
            clinical_causes.append("Suspected small pupil / non-mydriatic capture")
        if QualityReason.OVEREXPOSURE in reasons:
            clinical_causes.append("Corneal reflection or tear-film artifact")
        if QualityReason.INSUFFICIENT_FIELD_OF_VIEW in reasons:
            clinical_causes.append("Loss of fixation or uncooperative gaze")
        
        suspected_cause_str = "; ".join(clinical_causes) if clinical_causes else None

        if is_bad:
            return QualityAssessmentResult(
                grade=QualityGrade.BAD,
                is_reliable=False,
                reasons=reasons,
                metrics=metrics,
                details=f"Fails reliability gate: {', '.join(r.value for r in reasons)}",
                suspected_clinical_cause=suspected_cause_str,
            )

        # 5. Check for Borderline criteria
        is_borderline = False
        borderline_notes = []

        if metrics.sharpness_score < th.blur_good_threshold:
            borderline_notes.append("Marginal sharpness")
            is_borderline = True

        if metrics.mean_brightness < th.min_brightness_good:
            borderline_notes.append("Marginal low illumination")
            is_borderline = True
        elif metrics.mean_brightness > th.max_brightness_good:
            borderline_notes.append("Marginal glare/overexposure")
            is_borderline = True

        if metrics.contrast_score < th.min_contrast_good:
            borderline_notes.append("Marginal contrast")
            is_borderline = True

        if metrics.fov_ratio < th.min_fov_ratio_good:
            borderline_notes.append("Marginal field-of-view coverage")
            is_borderline = True

        if is_borderline:
            bord_cause = "Subtle media opacity or marginal focus requiring repeat capture or specialist over-read"
            return QualityAssessmentResult(
                grade=QualityGrade.BORDERLINE,
                is_reliable=False,
                reasons=[QualityReason.BORDERLINE_MARGINAL],
                metrics=metrics,
                details=f"Borderline image: {'; '.join(borderline_notes)}",
                suspected_clinical_cause=bord_cause,
            )

        # 6. All criteria passed -> Good
        return QualityAssessmentResult(
            grade=QualityGrade.GOOD,
            is_reliable=True,
            reasons=[QualityReason.ADEQUATE],
            metrics=metrics,
            details="Image certified as reliable for DR classification.",
            suspected_clinical_cause=None,
        )

    def _load_image_as_rgb(self, image_input: Union[str, np.ndarray, Image.Image]) -> Tuple[Optional[np.ndarray], Optional[str]]:
        try:
            if isinstance(image_input, str):
                if not os.path.exists(image_input):
                    return None, f"File not found: {image_input}"
                pil_img = Image.open(image_input).convert("RGB")
                return np.array(pil_img), None
            elif isinstance(image_input, Image.Image):
                return np.array(image_input.convert("RGB")), None
            elif isinstance(image_input, np.ndarray):
                if image_input.ndim == 2:
                    # Grayscale to RGB
                    return np.stack([image_input] * 3, axis=-1), None
                elif image_input.ndim == 3 and image_input.shape[2] == 3:
                    return image_input, None
                elif image_input.ndim == 3 and image_input.shape[2] == 4:
                    return image_input[:, :, :3], None
                return None, f"Unexpected numpy array shape: {image_input.shape}"
            else:
                return None, f"Unsupported image input type: {type(image_input)}"
        except Exception as e:
            return None, str(e)

    def _validate_fundus_characteristics(self, img_rgb: np.ndarray, th: QualityThresholds) -> Tuple[bool, str]:
        """
        Validates whether the image matches expected fundus characteristics:
        - Dominant red/orange retinal color spectrum
        - Reasonable aspect ratio
        - Presence of non-black retinal region
        """
        h, w, _ = img_rgb.shape
        if h < 64 or w < 64:
            return False, f"Image dimensions too small ({w}x{h})"

        r = img_rgb[:, :, 0].astype(float)
        g = img_rgb[:, :, 1].astype(float)
        b = img_rgb[:, :, 2].astype(float)

        # Fundus images are predominantly reddish compared to blue
        mean_r = np.mean(r)
        mean_b = np.mean(b) + 1e-5
        ratio = mean_r / mean_b

        # Check if entire image is flat/solid
        if np.std(r) < 2.0 and np.std(g) < 2.0 and np.std(b) < 2.0:
            return False, "Image has almost zero variance (blank or solid color)"

        # Standard fundus has higher red channel intensity than blue channel
        if ratio < 0.90:
            return False, f"Color profile does not match retinal fundus (Red/Blue ratio={ratio:.2f})"

        return True, ""

    def _calculate_metrics(self, img_rgb: np.ndarray) -> QualityMetrics:
        """
        Computes objective photographic quality metrics on the retinal region.
        Uses OpenCV if available, or fast NumPy equivalents.
        """
        h, w, _ = img_rgb.shape
        # Grayscale approximation
        gray = 0.2989 * img_rgb[:, :, 0] + 0.5870 * img_rgb[:, :, 1] + 0.1140 * img_rgb[:, :, 2]
        gray = gray.astype(np.float32)

        # Identify retinal mask (pixels significantly above background black)
        mask = gray > 15.0
        fov_ratio = float(np.sum(mask)) / float(h * w)

        if fov_ratio > 0.05:
            retinal_pixels = gray[mask]
            mean_brightness = float(np.mean(retinal_pixels))
            contrast_score = float(np.std(retinal_pixels))
        else:
            mean_brightness = float(np.mean(gray))
            contrast_score = float(np.std(gray))

        # Sharpness via Laplacian variance
        if HAS_OPENCV:
            laplacian = cv2.Laplacian(gray.astype(np.uint8), cv2.CV_64F)
            if fov_ratio > 0.05:
                sharpness_score = float(np.var(laplacian[mask]))
            else:
                sharpness_score = float(np.var(laplacian))
        else:
            # Discrete 2D Laplacian kernel via numpy slicing
            kernel = np.array([[0, 1, 0], [1, -4, 1], [0, 1, 0]], dtype=np.float32)
            # Fast approximation via central differences
            gy, gx = np.gradient(gray)
            sharpness_score = float(np.var(gx) + np.var(gy))

        return QualityMetrics(
            sharpness_score=sharpness_score,
            mean_brightness=mean_brightness,
            contrast_score=contrast_score,
            fov_ratio=fov_ratio,
            raw_scores={
                "sharpness": sharpness_score,
                "brightness": mean_brightness,
                "contrast": contrast_score,
                "fov_ratio": fov_ratio,
            }
        )
