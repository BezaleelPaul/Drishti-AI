from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import List, Optional, Tuple
import numpy as np
from PIL import Image

try:
    import cv2
    HAS_OPENCV = True
except ImportError:
    HAS_OPENCV = False


@dataclass
class RetinalStructuresResult:
    optic_disc_center: Tuple[int, int]           # (x, y) coordinates
    optic_disc_radius: int
    fovea_center: Tuple[int, int]                # (x, y) coordinates
    vessel_mask: np.ndarray                      # 2D binary uint8 mask (255 for vessel, 0 background)
    microaneurysm_candidates: List[Tuple[int, int, int]] = field(default_factory=list) # (x, y, radius)
    exudate_mask: Optional[np.ndarray] = None    # 2D binary uint8 mask of bright lesions
    annotated_overlay: Optional[np.ndarray] = None # RGB image with clinical annotations
    vessel_density_pct: float = 0.0              # % of retinal area occupied by vessels
    min_fovea_distance_px: float = 999.0         # distance from closest lesion to fovea center
    csme_risk: str = "LOW"                       # Clinically Significant Macular Edema risk


class RetinalStructureSegmenter:
    """
    MathWorks SIH26038 Requirement #2:
    Retinal Structure Segmentation and Clinical Landmark Extraction:
    - Optic Disc (OD) & Fovea localization
    - Blood vessel tree segmentation
    - Microaneurysm candidates (sub-pixel top-hat morphology)
    - Exudate candidate segmentation
    - Combined annotated overlay for <30s ophthalmologist validation.
    """

    def __init__(self, use_dl_toolbox: bool = True):
        self.use_dl_toolbox = use_dl_toolbox
        self._fovea_od_dl_model = None

        if self.use_dl_toolbox:
            self._try_load_dl_models()

    def _try_load_dl_models(self):
        try:
            import fundus_image_toolbox as fit
            self._fovea_od_dl_model, _ = fit.load_fovea_od_model(device="cpu")
        except Exception:
            self._fovea_od_dl_model = None

    def segment_structures(self, img_rgb: np.ndarray) -> RetinalStructuresResult:
        """
        Extracts all anatomical landmarks, vessels, and lesion candidates.
        """
        h, w, _ = img_rgb.shape
        green = img_rgb[:, :, 1].astype(np.float32)
        gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY) if HAS_OPENCV else np.mean(img_rgb, axis=2).astype(np.uint8)
        retinal_mask = (gray > 18).astype(np.uint8) * 255

        # 1. Optic Disc and Fovea Localization
        od_center, od_radius, fovea_center = self._localize_od_and_fovea(img_rgb, green, retinal_mask)

        # 2. Blood Vessel Tree Segmentation
        vessel_mask = self._segment_vessels(green, retinal_mask)

        # 3. Exudate Candidate Segmentation (Bright yellow lesions outside optic disc)
        exudate_mask = self._segment_exudates(img_rgb, od_center, od_radius, retinal_mask)

        # 4. Microaneurysm Candidate Detection (Small dark red dots in green channel)
        ma_candidates = self._detect_microaneurysm_candidates(green, vessel_mask, retinal_mask)

        # 5. Composite Annotated Clinical Overlay (<30s specialist review)
        annotated_overlay = self._create_annotated_overlay(
            img_rgb, od_center, od_radius, fovea_center, vessel_mask, exudate_mask, ma_candidates
        )

        # 6. Quantitative Biomarkers & CSME / Macular Edema Risk
        retinal_pixels = max(int(np.count_nonzero(retinal_mask)), 1)
        vessel_pixels = int(np.count_nonzero(vessel_mask))
        vessel_density = float((vessel_pixels / retinal_pixels) * 100.0)

        # Compute minimum lesion distance to fovea center
        fx, fy = fovea_center
        min_dist = 999.0
        for cx, cy, _ in ma_candidates:
            d = float(np.sqrt((cx - fx) ** 2 + (cy - fy) ** 2))
            if d < min_dist:
                min_dist = d

        # Check exudates if any
        if exudate_mask is not None and HAS_OPENCV:
            ex_pts = np.argwhere(exudate_mask == 255)
            if len(ex_pts) > 0:
                # ex_pts is (y, x)
                dists = np.sqrt((ex_pts[:, 1] - fx) ** 2 + (ex_pts[:, 0] - fy) ** 2)
                min_ex_dist = float(np.min(dists))
                if min_ex_dist < min_dist:
                    min_dist = min_ex_dist

        # CSME Risk: Macular encroachment within 1.5x OD radius (~500-1500 microns)
        if min_dist < od_radius * 1.5 and len(ma_candidates) > 0:
            csme_risk = "HIGH (Macular Zone Encroached)"
        elif min_dist < od_radius * 2.5 and len(ma_candidates) > 0:
            csme_risk = "MODERATE (Paramacular Lesions)"
        else:
            csme_risk = "LOW (Extramacular)"

        return RetinalStructuresResult(
            optic_disc_center=od_center,
            optic_disc_radius=od_radius,
            fovea_center=fovea_center,
            vessel_mask=vessel_mask,
            microaneurysm_candidates=ma_candidates,
            exudate_mask=exudate_mask,
            annotated_overlay=annotated_overlay,
            vessel_density_pct=round(vessel_density, 1),
            min_fovea_distance_px=round(min_dist, 1) if min_dist < 999.0 else 0.0,
            csme_risk=csme_risk,
        )

    def _localize_od_and_fovea(
        self, img_rgb: np.ndarray, green: np.float32, retinal_mask: np.ndarray
    ) -> Tuple[Tuple[int, int], int, Tuple[int, int]]:
        h, w, _ = img_rgb.shape
        cy, cx = h // 2, w // 2
        approx_radius = int(min(h, w) * 0.08)

        # 1. Try deep learning model from toolbox
        if self._fovea_od_dl_model is not None:
            try:
                coords = self._fovea_od_dl_model.predict([img_rgb])[0] # [fovea_x, fovea_y, od_x, od_y]
                fx, fy, od_x, od_y = int(coords[0]), int(coords[1]), int(coords[2]), int(coords[3])
                return (od_x, od_y), approx_radius, (fx, fy)
            except Exception:
                pass

        # 2. Robust morphological fallback
        if HAS_OPENCV:
            # Optic disc has high red + green intensity (yellowish bright area)
            red = img_rgb[:, :, 0].astype(np.float32)
            intensity = (red * 0.6 + green * 0.4)
            # Smooth with large Gaussian to find global bright region
            blurred = cv2.GaussianBlur(intensity, (45, 45), 0)
            blurred[retinal_mask == 0] = 0
            
            # Find brightest centroid
            min_v, max_v, min_l, max_l = cv2.minMaxLoc(blurred)
            od_x, od_y = int(max_l[0]), int(max_l[1])

            # Fovea is roughly 2.5 disc diameters temporal to optic disc
            # If OD is on left half of retina, fovea is to the right (+X), and vice versa
            od_side = 1 if od_x < cx else -1
            fx = int(np.clip(od_x + od_side * approx_radius * 3.2, 50, w - 50))
            fy = int(np.clip(od_y + (cy - od_y) * 0.3, 50, h - 50))
            return (od_x, od_y), approx_radius, (fx, fy)

        # Default geometric center estimate
        return (int(w * 0.35), cy), approx_radius, (int(w * 0.60), cy)

    def _segment_vessels(self, green: np.float32, retinal_mask: np.ndarray) -> np.ndarray:
        h, w = green.shape
        if not HAS_OPENCV:
            return np.zeros((h, w), dtype=np.uint8)

        # Enhance green channel contrast using CLAHE
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        g_u8 = np.clip(green, 0, 255).astype(np.uint8)
        enhanced_g = clahe.apply(g_u8)

        # Morphological black-hat transform: extracts structures darker than background (blood vessels)
        kernel_bh = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
        blackhat = cv2.morphologyEx(enhanced_g, cv2.MORPH_BLACKHAT, kernel_bh)

        # Adaptive thresholding on black-hat response
        _, vessels = cv2.threshold(blackhat, 9, 255, cv2.THRESH_BINARY)
        vessels[retinal_mask == 0] = 0

        # Remove small isolated speckles (area < 20)
        num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(vessels)
        cleaned_vessels = np.zeros_like(vessels)
        for i in range(1, num_labels):
            if stats[i, cv2.CC_STAT_AREA] >= 20:
                cleaned_vessels[labels == i] = 255

        return cleaned_vessels

    def _segment_exudates(
        self, img_rgb: np.ndarray, od_center: Tuple[int, int], od_radius: int, retinal_mask: np.ndarray
    ) -> np.ndarray:
        h, w, _ = img_rgb.shape
        if not HAS_OPENCV:
            return np.zeros((h, w), dtype=np.uint8)

        # Exudates appear bright yellow (high red & green, lower blue)
        r = img_rgb[:, :, 0].astype(np.float32)
        g = img_rgb[:, :, 1].astype(np.float32)
        b = img_rgb[:, :, 2].astype(np.float32)

        # Exudate index: high intensity + yellow saturation
        exudate_metric = np.clip(r * 0.5 + g * 0.5 - b * 0.4, 0, 255).astype(np.uint8)

        # Mask out optic disc (OD is also bright and would trigger false positives)
        od_mask = np.zeros((h, w), dtype=np.uint8)
        cv2.circle(od_mask, od_center, int(od_radius * 1.5), 255, -1)
        exudate_metric[od_mask == 255] = 0
        exudate_metric[retinal_mask == 0] = 0

        # Threshold top 1.5% brightest pixels outside OD
        if np.max(exudate_metric) > 160:
            _, ex_thresh = cv2.threshold(exudate_metric, 175, 255, cv2.THRESH_BINARY)
            # Retain only focal clusters
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
            ex_cleaned = cv2.morphologyEx(ex_thresh, cv2.MORPH_OPEN, kernel)
            return ex_cleaned
        return np.zeros((h, w), dtype=np.uint8)

    def _detect_microaneurysm_candidates(
        self, green: np.float32, vessel_mask: np.ndarray, retinal_mask: np.ndarray
    ) -> List[Tuple[int, int, int]]:
        """
        Microaneurysms: Small isolated focal dark spots (< 15 px diameter).
        """
        if not HAS_OPENCV:
            return []

        h, w = green.shape
        g_u8 = np.clip(green, 0, 255).astype(np.uint8)

        # Bottom-hat transform highlights dark circular objects smaller than kernel
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
        blackhat = cv2.morphologyEx(g_u8, cv2.MORPH_BLACKHAT, kernel)

        # Mask out main vessels (MAs are adjacent to or isolated from major arcades)
        dilated_vessels = cv2.dilate(vessel_mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)))
        blackhat[dilated_vessels == 255] = 0
        blackhat[retinal_mask == 0] = 0

        # Threshold candidate spots
        _, ma_thresh = cv2.threshold(blackhat, 15, 255, cv2.THRESH_BINARY)
        contours, _ = cv2.findContours(ma_thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        candidates = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if 3 <= area <= 65:  # sub-pixel/small lesion range
                (x, y), radius = cv2.minEnclosingCircle(cnt)
                candidates.append((int(x), int(y), max(int(radius), 3)))

        return candidates[:35]  # cap to top candidates to avoid clutter

    def _create_annotated_overlay(
        self,
        orig_rgb: np.ndarray,
        od_center: Tuple[int, int],
        od_radius: int,
        fovea_center: Tuple[int, int],
        vessel_mask: np.ndarray,
        exudate_mask: np.ndarray,
        ma_candidates: List[Tuple[int, int, int]],
    ) -> np.ndarray:
        """
        Blends all anatomical landmarks and lesion indicators onto original image
        for an instant <30s ophthalmology over-read.
        """
        overlay = orig_rgb.copy()
        if not HAS_OPENCV:
            return overlay

        # 1. Overlay Blood Vessels in light cyan tint
        vessel_pixels = vessel_mask == 255
        overlay[vessel_pixels, 0] = np.uint8(overlay[vessel_pixels, 0] * 0.4 + 40)
        overlay[vessel_pixels, 1] = np.uint8(overlay[vessel_pixels, 1] * 0.5 + 180)
        overlay[vessel_pixels, 2] = np.uint8(overlay[vessel_pixels, 2] * 0.5 + 230)

        # 2. Draw Optic Disc (yellow circle) & Fovea (blue crosshair)
        cv2.circle(overlay, od_center, od_radius, (255, 230, 0), 2)
        cv2.putText(overlay, "Optic Disc", (od_center[0] - 35, od_center[1] - od_radius - 6),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 230, 0), 1, cv2.LINE_AA)

        fx, fy = fovea_center
        cv2.drawMarker(overlay, (fx, fy), (0, 180, 255), cv2.MARKER_CROSS, 20, 2)
        cv2.circle(overlay, (fx, fy), 18, (0, 180, 255), 1)
        cv2.putText(overlay, "Fovea", (fx - 20, fy - 24),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 180, 255), 1, cv2.LINE_AA)

        # 3. Highlight Exudate Clusters in bright yellow outline
        if exudate_mask is not None and np.sum(exudate_mask) > 0:
            ex_contours, _ = cv2.findContours(exudate_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            cv2.drawContours(overlay, ex_contours, -1, (255, 255, 50), 1)

        # 4. Highlight Microaneurysm candidates with red circle markers
        for cx, cy, cr in ma_candidates:
            cv2.circle(overlay, (cx, cy), cr + 2, (255, 40, 40), 1)

        return overlay
