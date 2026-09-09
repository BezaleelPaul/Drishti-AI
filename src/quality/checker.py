from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from typing import Optional, Tuple, Union
import numpy as np
from PIL import Image

# Ensure external/fundus_image_toolbox is accessible
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_TOOLBOX_PATH = os.path.join(_PROJECT_ROOT, "external", "fundus_image_toolbox")
if os.path.exists(_TOOLBOX_PATH) and _TOOLBOX_PATH not in sys.path:
    sys.path.insert(0, _TOOLBOX_PATH)

try:
    import cv2
    HAS_OPENCV = True
except ImportError:
    HAS_OPENCV = False

# Native toolbox integration
try:
    from fundus_image_toolbox import (
        crop as fit_circle_crop,
        load_quality_ensemble,
        ensemble_predict_quality,
    )
    HAS_TOOLBOX = True
except Exception:
    HAS_TOOLBOX = False

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

    # ML Quality Confidence threshold [0.0 - 1.0]
    min_ml_quality_good: float = 0.70
    min_ml_quality_bad: float = 0.38

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
            min_ml_quality_good=0.80,
            min_ml_quality_bad=0.48,
        )

    @classmethod
    def for_remidio_fop(cls) -> QualityThresholds:
        """Remidio Fundus-on-Phone: Handheld smartphone camera with smaller sensor and slight edge glare."""
        return cls(
            blur_good_threshold=65.0,
            blur_bad_threshold=28.0,
            min_brightness_good=32.0,
            min_brightness_bad=18.0,
            max_brightness_good=225.0,
            min_contrast_good=13.0,
            min_contrast_bad=5.5,
            min_fov_ratio_good=0.30,
            min_ml_quality_good=0.65,
            min_ml_quality_bad=0.35,
        )

    @classmethod
    def for_forus_3nethra(cls) -> QualityThresholds:
        """Forus 3nethra Classic: Non-mydriatic portable camera built for Indian rural PHCs."""
        return cls(
            blur_good_threshold=75.0,
            blur_bad_threshold=32.0,
            min_brightness_good=35.0,
            min_brightness_bad=19.0,
            max_brightness_good=215.0,
            min_contrast_good=14.0,
            min_contrast_bad=6.0,
            min_fov_ratio_good=0.32,
            min_ml_quality_good=0.68,
            min_ml_quality_bad=0.36,
        )

    @classmethod
    def for_volk_inview(cls) -> QualityThresholds:
        """Volk iNview: Smartphone-mounted 20D indirect condensing lens with circular aperture."""
        return cls(
            blur_good_threshold=60.0,
            blur_bad_threshold=25.0,
            min_brightness_good=30.0,
            min_brightness_bad=15.0,
            min_contrast_good=12.0,
            min_contrast_bad=5.0,
            min_fov_ratio_good=0.22,
            min_ml_quality_good=0.62,
            min_ml_quality_bad=0.32,
        )


class ImageQualityChecker:
    """
    Model 1: Image Quality Assessment Engine.
    Evaluates retinal image trustworthiness without modifying original pixels.
    Supports native berenslab/fundus_image_toolbox ML ensemble and dynamic contour ROI extraction,
    with robust multi-scale feature fusion fallback for ultra-reliable edge deployment.
    Outputs: Good / Borderline / Bad (3-class) with specific rejection reason codes.
    """

    def __init__(
        self,
        thresholds: Optional[QualityThresholds] = None,
        use_dl_toolbox: bool = True,
        device: str = "cpu",
    ):
        self.thresholds = thresholds or QualityThresholds()
        self.strict_thresholds = QualityThresholds.strict()
        self.use_dl_toolbox = use_dl_toolbox
        self.device = device
        self._dl_ensemble = None

        if self.use_dl_toolbox and HAS_TOOLBOX:
            self._try_load_toolbox_ensemble()

    def _try_load_toolbox_ensemble(self):
        """Attempts to load the deep 10-model quality ensemble from fundus_image_toolbox."""
        try:
            self._dl_ensemble = load_quality_ensemble(device=self.device)
        except Exception:
            # Offline or weights not downloaded yet; fallback to multi-scale adaptive fusion
            self._dl_ensemble = None

    def assess_image(
        self,
        image_input: Union[str, np.ndarray, Image.Image],
        strict_mode: bool = False,
    ) -> QualityAssessmentResult:
        """
        Assesses image quality against objective photographic & deep learning criteria.
        
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

        # 3. Compute dynamic ROI & photographic/ML quality metrics
        metrics = self._calculate_metrics(np_img)
        ml_score = metrics.raw_scores.get("ml_quality_score", 1.0)

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

        # ML Quality Model Hard Cutoff
        if ml_score < th.min_ml_quality_bad and not is_bad:
            reasons.append(QualityReason.SEVERE_BLUR)
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
                details=f"Fails reliability gate: {', '.join(r.value for r in reasons)} (ML Quality: {ml_score:.2f})",
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

        if ml_score < th.min_ml_quality_good:
            borderline_notes.append(f"Marginal ML quality index ({ml_score:.2f} < {th.min_ml_quality_good:.2f})")
            is_borderline = True

        if is_borderline:
            bord_cause = "Subtle media opacity or marginal focus requiring repeat capture or specialist over-read"
            return QualityAssessmentResult(
                grade=QualityGrade.BORDERLINE,
                is_reliable=False,
                reasons=[QualityReason.BORDERLINE_MARGINAL],
                metrics=metrics,
                details=f"Borderline image: {'; '.join(borderline_notes)} (ML Quality: {ml_score:.2f})",
                suspected_clinical_cause=bord_cause,
            )

        # 6. All criteria passed -> Good
        return QualityAssessmentResult(
            grade=QualityGrade.GOOD,
            is_reliable=True,
            reasons=[QualityReason.ADEQUATE],
            metrics=metrics,
            details=f"Image certified as reliable for DR classification (ML Quality: {ml_score:.2f}).",
            suspected_clinical_cause=None,
        )

    def _load_image_as_rgb(
        self, image_input: Union[str, np.ndarray, Image.Image]
    ) -> Tuple[Optional[np.ndarray], Optional[str]]:
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
        - Non-zero variance (not blank or solid color)
        - Sufficient pixel resolution
        """
        h, w, _ = img_rgb.shape
        if h < 64 or w < 64:
            return False, f"Image dimensions too small ({w}x{h})"

        r = img_rgb[:, :, 0].astype(float)
        g = img_rgb[:, :, 1].astype(float)
        b = img_rgb[:, :, 2].astype(float)

        mean_r = np.mean(r)
        mean_b = np.mean(b) + 1e-5
        ratio = mean_r / mean_b

        # Check for blank / solid color
        if np.std(r) < 2.0 and np.std(g) < 2.0 and np.std(b) < 2.0:
            return False, "Image has almost zero variance (blank or solid color)"

        # Standard fundus has higher red channel intensity than blue channel
        if ratio < 0.90:
            return False, f"Color profile does not match retinal fundus (Red/Blue ratio={ratio:.2f})"

        return True, ""

    def _extract_dynamic_retinal_mask(self, img_rgb: np.ndarray) -> Tuple[np.ndarray, float]:
        """
        Extracts dynamic circular retinal mask using adaptive contour analysis
        or fundus_image_toolbox circle_crop.
        """
        h, w, _ = img_rgb.shape
        gray = 0.2989 * img_rgb[:, :, 0] + 0.5870 * img_rgb[:, :, 1] + 0.1140 * img_rgb[:, :, 2]
        gray_u8 = np.clip(gray, 0, 255).astype(np.uint8)

        if HAS_OPENCV:
            # Otsu thresholding + dynamic contour detection
            _, binary = cv2.threshold(gray_u8, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            # Filter small noise holes
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
            binary_closed = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
            contours, _ = cv2.findContours(binary_closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if contours:
                largest = max(contours, key=cv2.contourArea)
                mask = np.zeros((h, w), dtype=bool)
                cv2.drawContours(mask.astype(np.uint8), [largest], -1, 1, -1)
                mask = mask.astype(bool)
                fov_ratio = float(np.sum(mask)) / float(h * w)
                if fov_ratio > 0.10:
                    return mask, fov_ratio

        # Fallback simple threshold
        mask = gray > 15.0
        fov_ratio = float(np.sum(mask)) / float(h * w)
        return mask, fov_ratio

    def _calculate_metrics(self, img_rgb: np.ndarray) -> QualityMetrics:
        """
        Computes multi-scale photographic quality metrics and ML-driven quality score.
        """
        h, w, _ = img_rgb.shape
        gray = 0.2989 * img_rgb[:, :, 0] + 0.5870 * img_rgb[:, :, 1] + 0.1140 * img_rgb[:, :, 2]
        gray = gray.astype(np.float32)

        # 1. Dynamic Retinal ROI Isolation
        mask, fov_ratio = self._extract_dynamic_retinal_mask(img_rgb)

        if fov_ratio > 0.05 and np.any(mask):
            retinal_pixels = gray[mask]
            mean_brightness = float(np.mean(retinal_pixels))
            contrast_score = float(np.std(retinal_pixels))
        else:
            mean_brightness = float(np.mean(gray))
            contrast_score = float(np.std(gray))

        # 2. Multi-scale Sharpness (Laplacian variance on retinal area)
        if HAS_OPENCV:
            laplacian = cv2.Laplacian(gray.astype(np.uint8), cv2.CV_64F)
            if fov_ratio > 0.05 and np.any(mask):
                sharpness_score = float(np.var(laplacian[mask]))
            else:
                sharpness_score = float(np.var(laplacian))
        else:
            gy, gx = np.gradient(gray)
            sharpness_score = float(np.var(gx) + np.var(gy))

        # 3. Native ML Quality Prediction (Toolbox Ensemble or Multi-scale Fusion)
        ml_score = None
        engine_used = "MultiScale_Adaptive_Fusion"

        if self._dl_ensemble is not None and HAS_TOOLBOX:
            try:
                # ensemble_predict_quality returns probability of gradability [0.0 - 1.0]
                dl_preds, _ = ensemble_predict_quality(
                    self._dl_ensemble,
                    img_rgb,
                    img_size=512,
                    threshold=0.5,
                )
                ml_score = float(np.clip(dl_preds[0], 0.0, 1.0))
                engine_used = "FIT_DeepEnsemble"
            except Exception:
                ml_score = None

        if ml_score is None:
            # Calibrated Multi-Scale Feature Fusion (EyeQ / MCF-Net inspired)
            # S_blur: sigmoid mapping around typical clinical sharpness
            s_blur = 1.0 / (1.0 + np.exp(-0.05 * (sharpness_score - 55.0)))
            # S_illum: Gaussian centered at optimal clinical illumination (115)
            s_illum = np.exp(-((mean_brightness - 115.0) ** 2) / (2.0 * (55.0 ** 2)))
            # S_contrast: sigmoid mapping for dynamic range
            s_contrast = 1.0 / (1.0 + np.exp(-0.25 * (contrast_score - 12.0)))
            # S_fov: circular coverage penalty
            s_fov = np.clip(fov_ratio / 0.35, 0.0, 1.0)

            ml_score = float(np.clip(
                0.40 * s_blur + 0.30 * s_illum + 0.20 * s_contrast + 0.10 * s_fov,
                0.0, 1.0
            ))

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
                "ml_quality_score": ml_score,
                "quality_engine": engine_used,
            },
        )
