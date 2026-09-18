from pathlib import Path

import pytest

from api.services import ai_bridge
from api.services.ai_bridge import AIBridge


class _ClinicalBackend:
    def get_backend(self):
        return "keras"


def test_invalid_image_is_rejected_before_result_directory_creation(tmp_path, monkeypatch):
    monkeypatch.setattr(ai_bridge, "_RESULTS_DIR", str(tmp_path))
    bridge = AIBridge.__new__(AIBridge)
    bridge.dr_classifier = _ClinicalBackend()

    with pytest.raises(ValueError, match="Invalid image file"):
        bridge.analyze_retina(b"not-an-image", patient_id="PT-TEST")

    assert list(Path(tmp_path).iterdir()) == []