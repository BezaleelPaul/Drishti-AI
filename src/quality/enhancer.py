from __future__ import annotations

import os
import sys
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

try:
    from fundus_image_toolbox import crop as fit_circle_crop
    HAS_TOOLBOX_CROP = True
except Exception:
    HAS_TOOLBOX_CROP = False


class AdaptiveQualityEnhancer:
    """
    MathWorks SIH26038 Requirement #1:
    Adaptive enhancement for borderline fundus images:
    - Dynamic circular ROI extraction (via berenslab/fundus_image_toolbox EyeQ algorithm)
    - Dynamic Contrast-Limited Adaptive Histogram Equalization (CLAHE) in CIELAB space
    - Low-frequency background illumination bias correction
    - Bilateral edge-preserving denoising
    
    Provides an enhanced visual inspection layer for human operators
    while strictly preserving clinical audit compliance.
    """

    def __init__(self, clip_limit: float = 2.5, tile_grid_size: tuple = (8, 8)):
        self.clip_limit = clip_limit
        self.tile_grid_size = tile_grid_size

    def dynamic_circle_crop(
        self,
        img_rgb: np.ndarray,
        size: int = 512,
        return_mask: bool = False
    ) -> Union[np.ndarray, Tuple[np.ndarray, np.ndarray]]:
        """
        Applies automated contour-based circular cropping.
        Removes dark boundary edges and camera frame margins dynamically.
        """
        if HAS_TOOLBOX_CROP:
            try:
                cropped, mask, center, radius = fit_circle_crop(
                    img_rgb, size=size, return_all=True, to_numpy=True
                )
                if return_mask:
                    return cropped, mask
                return cropped
            except Exception:
                pass

        # Robust OpenCV fallback contour crop
        if HAS_OPENCV:
            h, w, _ = img_rgb.shape
            gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
            _, thresh = cv2.threshold(gray, 15, 255, cv2.THRESH_BINARY)
            contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if contours:
                c = max(contours, key=cv2.contourArea)
                (x, y), radius = cv2.minEnclosingCircle(c)
                center = (int(x), int(y))
                r = max(int(radius), 10)
                x1, y1 = max(0, center[0] - r), max(0, center[1] - r)
                x2, y2 = min(w, center[0] + r), min(h, center[1] + r)
                cropped = img_rgb[y1:y2, x1:x2]
                cropped_resized = cv2.resize(cropped, (size, size))
                mask = np.zeros((size, size), dtype=np.uint8)
                cv2.circle(mask, (size // 2, size // 2), size // 2, 255, -1)
                if return_mask:
                    return cropped_resized, mask
                return cropped_resized

        resized = np.array(Image.fromarray(img_rgb).resize((size, size)))
        if return_mask:
            return resized, np.ones((size, size), dtype=np.uint8) * 255
        return resized

    def enhance_borderline_image(self, img_rgb: np.ndarray) -> np.ndarray:
        """
        Applies adaptive CLAHE, illumination normalization, and denoising.
        Preserves color fidelity by processing strictly in LAB / Luminance color space.
        """
        h, w, _ = img_rgb.shape
        if not HAS_OPENCV:
            # Fallback contrast stretch
            p2, p98 = np.percentile(img_rgb, (2, 98))
            return np.clip((img_rgb - p2) / (p98 - p2 + 1e-5) * 255.0, 0, 255).astype(np.uint8)

        # 1. Convert to LAB color space to decouple luminance from chrominance
        lab = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2LAB)
        l_chan, a_chan, b_chan = cv2.split(lab)

        # 2. Dynamic parameter adaptation based on local luminance standard deviation
        local_contrast = float(np.std(l_chan))
        adapted_clip = self.clip_limit
        if local_contrast < 12.0:
            adapted_clip = min(self.clip_limit * 1.4, 4.0)  # Boost low contrast
        elif local_contrast > 25.0:
            adapted_clip = max(self.clip_limit * 0.8, 1.5)  # Moderate high contrast

        # 3. Illumination Normalization (estimate spatial low-frequency background bias)
        kernel_size = int(min(h, w) * 0.15) | 1  # ensure odd size
        background = cv2.GaussianBlur(l_chan, (kernel_size, kernel_size), 0)
        mean_l = float(np.mean(l_chan))
        norm_l = np.clip((l_chan.astype(np.float32) / (background.astype(np.float32) + 1e-5)) * mean_l, 0, 255).astype(np.uint8)

        # 4. Adaptive CLAHE on normalized luminance channel
        clahe = cv2.createCLAHE(clipLimit=adapted_clip, tileGridSize=self.tile_grid_size)
        enhanced_l = clahe.apply(norm_l)

        # 5. Bilateral Denoising (smooths sensor noise while preserving sharp vessel borders)
        denoised_l = cv2.bilateralFilter(enhanced_l, d=5, sigmaColor=35, sigmaSpace=35)

        # 6. Recombine channels and convert back to RGB
        enhanced_lab = cv2.merge([denoised_l, a_chan, b_chan])
        enhanced_rgb = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2RGB)

        # Preserve black non-retinal background boundary
        gray_orig = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
        mask = gray_orig > 12
        result = np.zeros_like(img_rgb)
        result[mask] = enhanced_rgb[mask]

        return result
