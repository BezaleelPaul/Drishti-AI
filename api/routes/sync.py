from __future__ import annotations

import base64
from typing import List
from fastapi import APIRouter

from api.schemas import OfflineSyncBatchRequest, OfflineSyncBatchResponse
from api.services.ai_bridge import AIBridge

router = APIRouter(prefix="/sync", tags=["Offline Synchronization"])


@router.post("", response_model=OfflineSyncBatchResponse)
def synchronize_offline_batch(payload: OfflineSyncBatchRequest):
    """
    Synchronizes offline screening records stored locally during rural field camps.
    Processes queued images, generates official diagnostic reports, and flags doctor reviews.
    """
    bridge = AIBridge.get_instance()
    synced_ids = []
    failed_items = []

    for item in payload.screenings:
        try:
            # Decode base64 image
            image_bytes = base64.b64decode(item.image_base64)
            analysis = bridge.analyze_retina(
                image_bytes=image_bytes,
                patient_id=item.patient_id,
                eye_side=item.eye_side,
                camera_profile=item.camera_profile or "Generic Fundus Camera",
            )
            synced_ids.append(analysis["screening_id"])
        except Exception as e:
            failed_items.append({
                "local_screening_id": item.local_screening_id,
                "error": str(e),
            })

    return OfflineSyncBatchResponse(
        total_received=len(payload.screenings),
        total_synced=len(synced_ids),
        failed_items=failed_items,
        synced_screening_ids=synced_ids,
    )
