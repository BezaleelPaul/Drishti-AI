from __future__ import annotations

import os

import numpy as np
from PIL import Image

# Configure TensorFlow env vars BEFORE keras is lazily imported below.
from src.tf_config import configure_tensorflow

configure_tensorflow()

from src.pipeline.schema import DRClassificationResult, DRGrade


class ClinicalModelUnavailableError(RuntimeError):
    """Raised when clinical inference cannot run with real model weights."""


class DRClassifier:
    """
    Model 2: Diabetic Retinopathy 5-Class Severity Classifier.
    Trained on APTOS 2019 dataset.
    Grades:
      0 - No DR
      1 - Mild NPDR
      2 - Moderate NPDR
      3 - Severe NPDR
      4 - Proliferative DR
    Referable DR: Grade >= 2
    """

    CLASS_LABELS = (
        "No DR",
        "Mild NPDR",
        "Moderate NPDR",
        "Severe NPDR",
        "Proliferative DR",
    )

    def __init__(
        self,
        onnx_model_path: str | None = None,
        keras_model_path: str | None = None,
        pytorch_model_path: str | None = None,
        device: str = "cpu",
    ):
        self.device = device
        self.onnx_model_path = onnx_model_path
        self.keras_model_path = keras_model_path
        self.pytorch_model_path = pytorch_model_path
        self.model_backend = "mock"
        self.load_error: str | None = None
        self._onnx_session = None
        self._keras_model = None
        self._torch_model = None
        self.thresholds = [0.5, 1.5, 2.5, 3.5]

        # Auto-detect pretrained model candidates in models/, root, or external
        repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        onnx_candidates = [
            os.path.join(repo_root, "models", "efficientnet_b0_regression_512px.onnx"),
            os.path.join(repo_root, "flutter_app", "assets", "models", "efficientnet_b0_regression_512px.onnx"),
            os.path.join(repo_root, "release", "models", "efficientnet_b0_regression_512px.onnx"),
            os.path.join(repo_root, "efficientnet_b0_regression_512px.onnx"),
        ]
        if not self.onnx_model_path:
            for op in onnx_candidates:
                if os.path.exists(op):
                    self.onnx_model_path = op
                    break

        candidate_keras_paths = [
            os.path.join(repo_root, "final_model.keras"),
            os.path.join(repo_root, "external", "DR-EfficientNetB0", "final_model.keras"),
        ]
        if not self.keras_model_path:
            for cp in candidate_keras_paths:
                if os.path.exists(cp):
                    self.keras_model_path = cp
                    break

        self._initialize_model()

    def _initialize_model(self):
        import logging

        # 1. Prioritize winning ONNX model (DRDetect Ordinal Regression)
        if self.onnx_model_path and os.path.exists(self.onnx_model_path):
            try:
                import onnxruntime as ort

                providers = ["CPUExecutionProvider"]
                self._onnx_session = ort.InferenceSession(self.onnx_model_path, providers=providers)
                self.model_backend = "onnx_drdetect"
                self.load_error = None
                logging.getLogger(__name__).info(f"Loaded DRDetect ONNX model: {self.onnx_model_path}")
                return
            except Exception as e:
                self.load_error = f"onnx load failed ({self.onnx_model_path}): {type(e).__name__}: {e}"
                logging.getLogger(__name__).warning(self.load_error)

        # 2. Try loading Keras model if available
        if self.keras_model_path and os.path.exists(self.keras_model_path):
            try:
                import keras

                self._keras_model = keras.saving.load_model(self.keras_model_path)
                self.model_backend = "keras"
                self.load_error = None
                return
            except Exception as e:
                self.load_error = (
                    f"keras load failed ({self.keras_model_path}): {type(e).__name__}: {e}"
                )
                logging.getLogger(__name__).warning(self.load_error)

        # 3. Try loading PyTorch model
        if self.pytorch_model_path and os.path.exists(self.pytorch_model_path):
            try:
                import torch

                try:
                    self._torch_model = torch.load(
                        self.pytorch_model_path, map_location=self.device, weights_only=True
                    )
                except TypeError:
                    self._torch_model = torch.load(
                        self.pytorch_model_path, map_location=self.device
                    )
                self._torch_model.eval()
                self.model_backend = "pytorch"
                self.load_error = None
                return
            except Exception as e:
                self.load_error = (
                    f"torch load failed ({self.pytorch_model_path}): {type(e).__name__}: {e}"
                )
                logging.getLogger(__name__).warning(self.load_error)

        # 4. Simulation fallback
        import logging

        logging.getLogger(__name__).warning(
            "DRClassifier: no DL weights loaded, using simulated backend."
        )
        self.model_backend = "simulated"

    def get_onnx_session(self):
        return self._onnx_session

    def get_keras_model(self):
        return self._keras_model

    def get_torch_model(self):
        return self._torch_model

    def get_active_model(self):
        if self.model_backend == "keras":
            return self._keras_model
        elif self.model_backend == "pytorch":
            return self._torch_model
        return None

    def get_backend(self) -> str:
        return self.model_backend

    def predict(self, image_input: str | np.ndarray | Image.Image) -> DRClassificationResult:
        """
        Runs DR classification on a certified Reliable Original Image.
        Returns full 5-class probability distribution, top-1 confidence, and top2 margin.
        """
        # Load image strictly without clinical enhancement (Section 20 Non-destructive rule)
        pil_img = self._load_as_pil(image_input)

        if self.model_backend == "onnx_drdetect" and self._onnx_session is not None:
            return self._predict_onnx_drdetect(pil_img)
        elif self.model_backend == "keras" and self._keras_model is not None:
            return self._predict_keras(pil_img)
        elif self.model_backend == "pytorch" and self._torch_model is not None:
            return self._predict_pytorch(pil_img)
        else:
            return self._predict_simulated(pil_img)

    def _predict_onnx_drdetect(self, pil_img: Image.Image) -> DRClassificationResult:
        import cv2

        # 1. Preprocessing: crop dark border (tol=7) -> circle crop -> Ben Graham -> resize 512x512
        img_rgb = np.asarray(pil_img.convert("RGB"), dtype=np.uint8)
        gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
        mask = gray > 7
        if mask.any():
            row_idx = np.where(mask.any(axis=1))[0]
            col_idx = np.where(mask.any(axis=0))[0]
            cropped = img_rgb[row_idx[0]:row_idx[-1] + 1, col_idx[0]:col_idx[-1] + 1]
        else:
            cropped = img_rgb

        h, w = cropped.shape[:2]
        radius = min(h, w) // 2
        cx, cy = w // 2, h // 2
        circ_mask = np.zeros((h, w), dtype=np.uint8)
        cv2.circle(circ_mask, (cx, cy), radius, 255, -1)
        circled = cv2.bitwise_and(cropped, cropped, mask=circ_mask)[cy - radius:cy + radius, cx - radius:cx + radius]

        blurred = cv2.GaussianBlur(circled, (0, 0), 20)
        enhanced = cv2.addWeighted(circled, 4, blurred, -4, 128)
        resized = cv2.resize(enhanced, (512, 512), interpolation=cv2.INTER_AREA)

        # ImageNet normalization
        norm_01 = resized.astype(np.float32) / 255.0
        mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
        std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
        normalized = (norm_01 - mean) / std

        # NCHW format
        chw = np.transpose(normalized, (2, 0, 1))
        inp_tensor = np.expand_dims(chw, axis=0).astype(np.float32)

        # 2. Run ONNX Inference
        inp_name = self._onnx_session.get_inputs()[0].name
        out = self._onnx_session.run(None, {inp_name: inp_tensor})[0]
        score = float(np.squeeze(out))

        # 3. Decode continuous ordinal regression score
        grade_val = 0
        for th in self.thresholds:
            if score > th:
                grade_val += 1
        grade_val = min(4, max(0, grade_val))
        grade = DRGrade(grade_val)

        # 4. Uncertainty & Synthetic Soft Distribution for backward compatibility
        dist_to_boundary = min(abs(score - th) for th in self.thresholds)
        uncertainty = float(np.exp(-dist_to_boundary))

        # Honest probabilities approximation centered around continuous grade score
        sigma = 0.65
        raw_probs = [float(np.exp(-0.5 * ((c - score) / sigma) ** 2)) for c in range(5)]
        total_p = sum(raw_probs)
        probs = [p / total_p for p in raw_probs]

        sorted_indices = np.argsort(probs)[::-1]
        top1_idx = int(sorted_indices[0])
        top2_idx = int(sorted_indices[1])
        top1_conf = float(probs[top1_idx])
        margin = float(top1_conf - probs[top2_idx])

        return DRClassificationResult(
            predicted_grade=grade,
            probabilities=probs,
            confidence=top1_conf,
            top2_margin=margin,
            is_referable=score >= 1.5,
            raw_score=score,
            uncertainty=uncertainty,
            model_id="drdetect_ordinal",
        )

    def _load_as_pil(self, image_input: str | np.ndarray | Image.Image) -> Image.Image:
        try:
            from src.image_io import to_rgb_uint8

            if isinstance(image_input, str):
                # Shared funnel: dimension cap applies to file paths too.
                return Image.fromarray(
                    to_rgb_uint8(np.array(Image.open(image_input).convert("RGB")))
                )
            elif isinstance(image_input, np.ndarray):
                # Single shared loader (float scale, NaN fail-closed, 2D/RGBA
                # handled). See src/image_io.
                arr = to_rgb_uint8(image_input)
                return Image.fromarray(arr).convert("RGB")
            elif isinstance(image_input, Image.Image):
                return Image.fromarray(to_rgb_uint8(np.array(image_input.convert("RGB"))))
            else:
                raise TypeError(f"Unsupported image type: {type(image_input)}")
        except FileNotFoundError:
            raise ValueError(f"Image file not found: {image_input}")
        except (OSError, ValueError):
            raise
        except Exception as e:  # noqa: BLE001 - normalize decoder failures
            raise ValueError(f"Could not decode image input: {e}")

    def _predict_keras(self, pil_img: Image.Image) -> DRClassificationResult:
        img_resized = pil_img.resize((224, 224))
        arr = np.expand_dims(np.array(img_resized, dtype=np.float32), axis=0)
        # Model's internal preprocessing handles normalization
        preds = self._keras_model.predict(arr, verbose=0)[0]
        probs = [float(p) for p in preds]
        return self._build_result(probs)

    def _predict_pytorch(self, pil_img: Image.Image) -> DRClassificationResult:
        import torch
        from torchvision import transforms

        transform = transforms.Compose(
            [
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
            ]
        )
        # Validate device, fallback to cpu if cuda unavailable
        try:
            dev = str(self.device)
            if dev.startswith("cuda") and not torch.cuda.is_available():
                dev = "cpu"
        except Exception:  # noqa: BLE001 - invalid accelerator falls back to CPU
            dev = "cpu"
        try:
            self._torch_model.eval()
            self._torch_model.to(dev)
        except Exception:  # noqa: BLE001 - invalid model device falls back to CPU
            dev = "cpu"
        tensor = transform(pil_img).unsqueeze(0).to(dev)
        with torch.no_grad():
            logits = self._torch_model(tensor)
            probs = torch.softmax(logits, dim=-1).squeeze(0).cpu().numpy()
        return self._build_result([float(p) for p in probs])

    def _predict_simulated(self, pil_img: Image.Image) -> DRClassificationResult:
        """
        Simulated inference based on image features for test environments and unit tests.
        Derives realistic probabilities without crashing if heavy DL framework is missing.
        """
        arr = np.array(pil_img.resize((128, 128)), dtype=np.float32)
        # Red channel characteristics and variation
        r_mean = float(np.mean(arr[:, :, 0]))
        r_std = float(np.std(arr[:, :, 0]))

        # Pseudo-deterministic distribution from image features
        # Add hash of all channels to make distribution more unique
        g_mean = float(np.mean(arr[:, :, 1]))
        b_mean = float(np.mean(arr[:, :, 2]))
        image_hash = int((r_mean * 10000 + g_mean * 100 + b_mean * 10 + r_std) % 100000)

        # Pseudo-deterministic distribution from image features
        rng = np.random.RandomState(image_hash)
        raw = rng.dirichlet(alpha=[2.0, 1.0, 1.0, 0.5, 0.5])
        probs = [float(p) for p in raw]

        return self._build_result(probs)

    def _build_result(self, probs: list[float]) -> DRClassificationResult:
        probs = list(probs)
        if len(probs) != 5:
            raise ValueError(f"Expected 5-class probability vector, got {len(probs)}")
        # Ensure sum to 1
        total = sum(probs)
        if total <= 0 or not np.isfinite(total):
            raise ValueError("Invalid probability vector: sum must be positive and finite")
        probs = [p / total for p in probs]

        sorted_indices = np.argsort(probs)[::-1]
        top1_idx = int(sorted_indices[0])
        top2_idx = int(sorted_indices[1])

        top1_conf = float(probs[top1_idx])
        top2_conf = float(probs[top2_idx])
        margin = float(top1_conf - top2_conf)

        grade = DRGrade(top1_idx)
        return DRClassificationResult(
            predicted_grade=grade,
            probabilities=probs,
            confidence=top1_conf,
            top2_margin=margin,
            is_referable=grade.is_referable,
        )
