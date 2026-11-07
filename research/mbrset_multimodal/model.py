"""Research-only image + clinical fusion model; not a diagnostic device."""
from __future__ import annotations

import torch
from torch import nn
from torchvision.models import EfficientNet_B0_Weights, efficientnet_b0


class RetinalClinicalFusion(nn.Module):
    """EfficientNet-B0 image encoder plus normalized clinical vector."""

    def __init__(self, clinical_features: int, num_grades: int = 5, pretrained: bool = True):
        super().__init__()
        if clinical_features < 1:
            raise ValueError("clinical_features must be positive")
        weights = EfficientNet_B0_Weights.DEFAULT if pretrained else None
        backbone = efficientnet_b0(weights=weights)
        self.image_encoder = backbone.features
        self.image_pool = nn.AdaptiveAvgPool2d(1)
        self.image_projection = nn.Sequential(
            nn.Flatten(),
            nn.Linear(1280, 256),
            nn.ReLU(),
            nn.Dropout(0.25),
        )
        self.clinical_encoder = nn.Sequential(
            nn.Linear(clinical_features * 2, 64),
            nn.ReLU(),
            nn.Dropout(0.15),
            nn.Linear(64, 64),
            nn.ReLU(),
        )
        self.fusion = nn.Sequential(
            nn.Linear(320, 128),
            nn.ReLU(),
            nn.Dropout(0.25),
            nn.Linear(128, num_grades),
        )

    def forward(self, image: torch.Tensor, clinical: torch.Tensor) -> torch.Tensor:
        if clinical.ndim != 2 or clinical.shape[1] % 2:
            raise ValueError("clinical input must contain [imputed_values, observed_mask]")
        image_features = self.image_projection(self.image_pool(self.image_encoder(image)))
        clinical_features = self.clinical_encoder(clinical)
        return self.fusion(torch.cat((image_features, clinical_features), dim=1))
