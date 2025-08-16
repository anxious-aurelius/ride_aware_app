import logging
from datetime import datetime, timezone
from fastapi import HTTPException
from services.db import feedback_collection, ride_history_collection

logger = logging.getLogger(__name__)


async def create_feedback_entry(device_id: str, threshold_id: str) -> None:
    await feedback_collection.update_one(
        {"threshold_id": threshold_id},
        {
            "$setOnInsert": {
                "device_id": device_id,
                "threshold_id": threshold_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
        },
        upsert=True,
    )


async def record_feedback(payload: dict) -> dict:
    device_id = payload.get("device_id")
    threshold_id = payload.get("threshold_id")
    if not device_id or not threshold_id:
        raise HTTPException(status_code=400, detail="device_id and threshold_id are required")

    feedback_summary = (payload.get("feedback_summary") or payload.get("summary") or "").strip()

    doc = {
        k: v
        for k, v in payload.items()
        if k not in {"_id"}  # sanitize just in case
    }
    doc["device_id"] = device_id
    doc["threshold_id"] = threshold_id
    doc.setdefault("created_at", datetime.now(timezone.utc).isoformat())

    await feedback_collection.update_one(
        {"threshold_id": threshold_id},
        {"$set": doc},
        upsert=True,
    )

    rh_update = {
        "$set": {
            "status": "completed",
            "feedback_summary": feedback_summary,
        },
        "$unset": {
            "feedback": ""
        },
    }
    await ride_history_collection.update_one({"threshold_id": threshold_id}, rh_update)

    logger.info(
        "Feedback saved and ride_history updated (completed) for threshold %s",
        threshold_id,
    )
    return {"status": "ok", "threshold_id": threshold_id}
