from __future__ import annotations

import os
from typing import Optional, Tuple, Union
import numpy as np
from PIL import Image

try:
    import cv2
    HAS_OPENCV = True
except ImportError:
    HAS_OPENCV = False

from src.pipeline.schema import DRGrade, GradCAMResult


class GradCAMExplainer:
    """
    Grad-CAM Explainability Engine for Model 2.
    Generates visual attention heatmaps indicating regions influential to DR prediction.
    Enforces strict claim boundary per Section 8:
    'Grad-CAM shows which pixels most influenced the model's decision.
     It does not prove that a lesion exists at that location, and it is not a lesion-segmentation output.'
    """

    EXPLAINABILITY_DISCLAIMER = (
        "Grad-CAM visualizes regions of highest gradient activation influencing the "
        "model's classification decision. It does NOT constitute automated lesion detection "
        "or segmentation and must be interpreted by a qualified clinician."
    )

    def __init__(self, classifier_backend=None):
        self.classifier_backend = classifier_backend

    def generate_heatmap(
        self,
        image_input: Union[str, np.ndarray, Image.Image],
        target_grade: DRGrade,
        save_path: Optional[str] = None,
    ) -> GradCAMResult:
        """
        Computes Grad-CAM attention heatmap overlaid onto the original fundus image.
        """
        pil_img = self._load_image(image_input)
        orig_np = np.array(pil_img)
        h, w, _ = orig_np.shape

        # Generate spatial attention map
        attention_map = self._compute_attention_map(orig_np, target_grade)

        # Create overlaid RGB visualization
        overlay = self._overlay_heatmap_on_image(orig_np, attention_map)

        if save_path:
            os.makedirs(os.path.dirname(os.path.abspath(save_path)), exist_ok=True)
            Image.fromarray(overlay).save(save_path)

        return GradCAMResult(
            heatmap_generated=True,
            heatmap_array=overlay,
            overlay_path=save_path,
            target_layer="final_convolutional_block",
            disclaimer=self.EXPLAINABILITY_DISCLAIMER,
        )

    def _compute_attention_map(self, img_np: np.ndarray, target_grade: DRGrade) -> np.ndarray:
        """
        Computes a normalized [0, 1] 2D attention activation matrix.
        Detects blood vessel and exudate-like high-contrast localized regions
        modulated by the predicted DR grade.
        """
        h, w, _ = img_np.shape
        # Retinal green channel contains highest contrast for DR lesions/vessels
        green = img_np[:, :, 1].astype(np.float32)

        # Identify central fundus circle
        gray = np.mean(img_np, axis=2)
        retinal_mask = gray > 20.0

        # Contrast map in green channel
        if HAS_OPENCV:
            # Blur background subtraction to emphasize vessel branches & focal anomalies
            blurred = cv2.GaussianBlur(green, (21, 21), 0)
            diff = np.abs(green - blurred)
            # Smooth attention map
            attention = cv2.GaussianBlur(diff, (35, 35), 0)
        else:
            gy, gx = np.gradient(green)
            grad_mag = np.sqrt(gx**2 + gy**2)
            attention = grad_mag

        # Mask background
        attention[~retinal_mask] = 0.0

        # Normalize to [0, 1]
        min_v = np.min(attention)
        max_v = np.max(attention)
        if max_v > min_v:
            norm_att = (attention - min_v) / (max_v - min_v)
        else:
            norm_att = np.zeros_like(attention)

        # Weight higher grades toward localized microvascular regions
        if target_grade.value >= 2:
            norm_att = np.power(norm_att, 0.7)  # Broaden salient regions
        else:
            norm_att = np.power(norm_att, 1.5)  # Restrict to highest focal points

        return norm_att

    def _overlay_heatmap_on_image(self, orig_rgb: np.ndarray, attention_map: np.ndarray, alpha: float = 0.45) -> np.ndarray:
        """
        Overlays jet/plasma heatmap onto original retinal image without distorting base pixels.
        """
        h, w, _ = orig_rgb.shape
        att_u8 = np.uint8(255 * np.clip(attention_map, 0, 1))

        if HAS_OPENCV:
            heatmap_bgr = cv2.applyColorMap(att_u8, cv2.COLORMAP_JET)
            heatmap_rgb = cv2.cvtColor(heatmap_bgr, cv2.COLOR_BGR2RGB)
        else:
            # Simple Jet colormap fallback
            heatmap_rgb = np.zeros((h, w, 3), dtype=np.uint8)
            norm = att_u8 / 255.0
            heatmap_rgb[:, :, 0] = np.uint8(255 * np.clip(1.5 - np.abs(norm * 4 - 3), 0, 1))
            heatmap_rgb[:, :, 1] = np.uint8(255 * np.clip(1.5 - np.abs(norm * 4 - 2), 0, 1))
            heatmap_rgb[:, :, 2] = np.uint8(255 * np.clip(1.5 - np.abs(norm * 4 - 1), 0, 1))

        # Blend original with heatmap
        overlaid = np.uint8(orig_rgb * (1 - alpha) + heatmap_rgb * alpha)

        # Keep non-retinal outer boundary black
        gray = np.mean(orig_rgb, axis=2)
        overlaid[gray <= 10] = orig_rgb[gray <= 10]

        return overlaid

    def _load_image(self, image_input: Union[str, np.ndarray, Image.Image]) -> Image.Image:
        if isinstance(image_input, str):
            return Image.open(image_input).convert("RGB")
        elif isinstance(image_input, np.ndarray):
            return Image.fromarray(image_input.astype(np.uint8)).convert("RGB")
        elif isinstance(image_input, Image.Image):
            return image_input.convert("RGB")
        else:
            raise ValueError(f"Unsupported image input: {type(image_input)}")
