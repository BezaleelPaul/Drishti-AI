"""Patient-grouped training entry point for the mBRSET fusion research model."""
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image
from sklearn.metrics import balanced_accuracy_score, cohen_kappa_score, f1_score, recall_score, confusion_matrix
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms

from research.mbrset_multimodal.model import RetinalClinicalFusion


class FusionDataset(Dataset):
    def __init__(self, frame, image_root, image_column, clinical_columns, grade_column, scaler, image_size):
        self.frame = frame.reset_index(drop=True)
        self.image_root = Path(image_root)
        self.image_column = image_column
        self.clinical_columns = clinical_columns
        self.grade_column = grade_column
        self.scaler = scaler
        self.transform = transforms.Compose([
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
        ])

    def __len__(self):
        return len(self.frame)

    def __getitem__(self, index):
        row = self.frame.iloc[index]
        path = Path(str(row[self.image_column]))
        if not path.is_absolute():
            path = self.image_root / path
        with Image.open(path) as image:
            image_tensor = self.transform(image.convert("RGB"))
        raw = pd.to_numeric(row[self.clinical_columns], errors="coerce").to_numpy(dtype=np.float32)
        observed = np.isfinite(raw).astype(np.float32)
        imputed = np.where(np.isfinite(raw), raw, self.scaler.mean_)
        clinical = np.concatenate([self.scaler.transform(imputed.reshape(1, -1))[0], observed])
        return image_tensor, torch.tensor(clinical, dtype=torch.float32), torch.tensor(int(row[self.grade_column]), dtype=torch.long)


def _split_by_patient(frame, patient_column, seed):
    groups = frame[patient_column].astype(str).to_numpy()
    first = GroupShuffleSplit(n_splits=1, test_size=0.20, random_state=seed)
    train_val_idx, test_idx = next(first.split(frame, groups=groups))
    train_val = frame.iloc[train_val_idx].copy()
    second = GroupShuffleSplit(n_splits=1, test_size=0.20, random_state=seed + 1)
    train_idx, val_idx = next(second.split(train_val, groups=train_val[patient_column].astype(str)))
    train, val, test = train_val.iloc[train_idx].copy(), train_val.iloc[val_idx].copy(), frame.iloc[test_idx].copy()
    sets = [set(x[patient_column].astype(str)) for x in (train, val, test)]
    if sets[0] & sets[1] or sets[0] & sets[2] or sets[1] & sets[2]:
        raise RuntimeError("Patient leakage detected across train/validation/test splits.")
    return train, val, test


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()
    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    required = ("metadata_csv", "image_root", "image_column", "patient_column", "grade_column", "clinical_columns")
    missing = [key for key in required if not cfg.get(key)]
    if missing:
        raise ValueError(f"Missing config keys: {missing}")
    seed = int(cfg.get("seed", 42))
    random.seed(seed); np.random.seed(seed); torch.manual_seed(seed)
    frame = pd.read_csv(cfg["metadata_csv"])
    columns = [cfg["image_column"], cfg["patient_column"], cfg["grade_column"], *cfg["clinical_columns"]]
    absent = [c for c in columns if c not in frame.columns]
    if absent:
        raise ValueError(f"Configured columns absent from metadata: {absent}")
    frame = frame.dropna(subset=[cfg["image_column"], cfg["patient_column"], cfg["grade_column"]]).copy()
    frame[cfg["grade_column"]] = pd.to_numeric(frame[cfg["grade_column"]], errors="coerce")
    frame = frame.dropna(subset=[cfg["grade_column"]])
    if not frame[cfg["grade_column"]].isin([0, 1, 2, 3, 4]).all():
        raise ValueError("DR grade labels must be integer values 0..4.")
    frame[cfg["grade_column"]] = frame[cfg["grade_column"]].astype(int)
    frame[cfg["clinical_columns"]] = frame[cfg["clinical_columns"]].apply(pd.to_numeric, errors="coerce")
    frame = frame[frame[cfg["clinical_columns"]].notna().any(axis=1)]
    image_root = Path(cfg["image_root"])
    def resolve(value):
        path = Path(str(value))
        return path if path.is_absolute() else image_root / path
    frame = frame[frame[cfg["image_column"]].map(resolve).map(Path.is_file)]
    if frame[cfg["patient_column"]].nunique() < 10:
        raise ValueError("At least 10 unique patients are required for a minimally useful grouped split.")
    train, val, test = _split_by_patient(frame, cfg["patient_column"], seed)
    scaler = StandardScaler()
    scaler.fit(train[cfg["clinical_columns"]])
    image_size = int(cfg.get("image_size", 224))
    batch_size = int(cfg.get("batch_size", 16))
    train_ds = FusionDataset(train, image_root, cfg["image_column"], cfg["clinical_columns"], cfg["grade_column"], scaler, image_size)
    val_ds = FusionDataset(val, image_root, cfg["image_column"], cfg["clinical_columns"], cfg["grade_column"], scaler, image_size)
    test_ds = FusionDataset(test, image_root, cfg["image_column"], cfg["clinical_columns"], cfg["grade_column"], scaler, image_size)
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False, num_workers=0)
    test_loader = DataLoader(test_ds, batch_size=batch_size, shuffle=False, num_workers=0)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = RetinalClinicalFusion(len(cfg["clinical_columns"]), pretrained=bool(cfg.get("pretrained", True))).to(device)
    counts = np.bincount(train[cfg["grade_column"]].to_numpy(), minlength=5)
    weights = len(train) / np.maximum(counts, 1) / 5
    criterion = nn.CrossEntropyLoss(weight=torch.tensor(weights, dtype=torch.float32, device=device))
    optimizer = torch.optim.AdamW(model.parameters(), lr=float(cfg.get("learning_rate", 1e-4)))
    output = Path(cfg.get("output_dir", "artifacts/mbrset_fusion")); output.mkdir(parents=True, exist_ok=True)

    def evaluate(loader):
        model.eval(); ys, preds = [], []
        with torch.no_grad():
            for images, clinical, labels in loader:
                logits = model(images.to(device), clinical.to(device))
                preds.extend(logits.argmax(1).cpu().numpy().tolist()); ys.extend(labels.numpy().tolist())
        return np.asarray(ys), np.asarray(preds)

    best = float("inf"); best_path = output / "best_fusion.pt"
    for epoch in range(int(cfg.get("epochs", 15))):
        model.train()
        for images, clinical, labels in train_loader:
            optimizer.zero_grad()
            loss = criterion(model(images.to(device), clinical.to(device)), labels.to(device))
            loss.backward(); optimizer.step()
        vy, vp = evaluate(val_loader)
        val_loss_proxy = 1.0 - f1_score(vy, vp, average="macro", zero_division=0)
        print(f"epoch={epoch + 1} val_macro_f1={1.0 - val_loss_proxy:.4f}")
        if val_loss_proxy < best:
            best = val_loss_proxy
            torch.save({"state_dict": model.cpu().state_dict(), "clinical_columns": cfg["clinical_columns"],
                        "scaler_mean": scaler.mean_.tolist(), "scaler_scale": scaler.scale_.tolist(),
                        "image_size": image_size}, best_path)
            model.to(device)

    checkpoint = torch.load(best_path, map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["state_dict"]); model.eval()
    y, pred = evaluate(test_loader)
    referable = y >= 2; pred_referable = pred >= 2
    metrics = {
        "test_images": int(len(y)), "test_patients": int(test[cfg["patient_column"]].nunique()),
        "macro_f1": float(f1_score(y, pred, average="macro", zero_division=0)),
        "balanced_accuracy": float(balanced_accuracy_score(y, pred)),
        "quadratic_weighted_kappa": float(cohen_kappa_score(y, pred, weights="quadratic")),
        "referable_dr_sensitivity": float(recall_score(referable, pred_referable, zero_division=0)),
        "referable_dr_specificity": float(recall_score(~referable, ~pred_referable, zero_division=0)),
        "confusion_matrix": confusion_matrix(y, pred, labels=[0, 1, 2, 3, 4]).tolist(),
        "warning": "Research evaluation only; not evidence of clinical validity or deployment readiness."
    }
    (output / "test_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    model.cpu()
    dummy_image = torch.zeros(1, 3, image_size, image_size)
    dummy_clinical = torch.zeros(1, len(cfg["clinical_columns"]) * 2)
    torch.onnx.export(model, (dummy_image, dummy_clinical), output / "fusion.onnx",
                      input_names=["fundus_image", "clinical_features"],
                      output_names=["dr_grade_logits"], dynamic_axes={"fundus_image": {0: "batch"},
                      "clinical_features": {0: "batch"}, "dr_grade_logits": {0: "batch"}}, opset_version=17)
    (output / "test_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
