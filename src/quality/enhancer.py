from __future__ import annotations

import numpy as np
from PIL import Image

try:
    import cv2
    HAS_OPENCV = True
except ImportError:
    HAS_OPENCV = False


class AdaptiveQualityEnhancer:
    """
    MathWorks SIH26038 Requirement #1:
    Adaptive enhancement for borderline fundus images:
    - Contrast-Limited Adaptive Histogram Equalization (CLAHE)
    - Background illumination normalization
    - Bilateral / Gaussian denoising
    
    Provides an enhanced visual inspection layer for human operators
    while maintaining clinical audit compliance.
    """

    def __init__(self, clip_limit: float = 2.5, tile_grid_size: tuple = (8, 8)):
        self.clip_limit = clip_limit
        self.tile_grid_size = tile_grid_size

    def enhance_borderline_image(self, img_rgb: np.ndarray) -> np.ndarray:
        """
        Applies adaptive CLAHE, illumination normalization, and denoising.
        Preserves color fidelity by processing in LAB / Luminance color space.
        """
        h, w, _ = img_rgb.shape
        if not HAS_OPENCV:
            # Fallback contrast stretch
            p2, p98 = np.percentile(img_rgb, (2, 98))
            return np.clip((img_rgb - p2) / (p98 - p2 + 1e-5) * 255.0, 0, 255).astype(np.uint8)

        # 1. Convert to LAB color space to decouple luminance from color channels
        lab = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2LAB)
        l_chan, a_chan, b_chan = cv2.split(lab)

        # 2. Illumination Normalization (estimate low-frequency background luminance)
        # Using large Gaussian kernel to estimate spatial illumination bias
        kernel_size = int(min(h, w) * 0.15) | 1  # ensure odd size
        background = cv2.GaussianBlur(l_chan, (kernel_size, kernel_size), 0)
        
        # Normalize: l_norm = (l / background) * mean_luminance
        mean_l = np.mean(l_chan)
        norm_l = np.clip((l_chan.astype(np.float32) / (background.astype(np.float32) + 1e-5)) * mean_l, 0, 255).astype(np.uint8)

        # 3. Adaptive CLAHE on normalized luminance channel
        clahe = cv2.createCLAHE(clipLimit=self.clip_limit, tileGridSize=self.tile_grid_size)
        enhanced_l = clahe.apply(norm_l)

        # 4. Bilateral Denoising (smooths sensor noise while preserving sharp vessel borders)
        denoised_l = cv2.bilateralFilter(enhanced_l, d=5, sigmaColor=35, sigmaSpace=35)

        # 5. Recombine channels and convert back to RGB
        enhanced_lab = cv2.merge([denoised_l, a_chan, b_chan])
        enhanced_rgb = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2RGB)

        # Preserve black non-retinal background boundary
        gray_orig = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
        mask = gray_orig > 12
        result = np.zeros_like(img_rgb)
        result[mask] = enhanced_rgb[mask]

        return result
