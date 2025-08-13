import logging
from datetime import datetime
from models.feedback import Feedback
from services.db import feedback_collection, ride_history_collection

logger = logging.getLogger(__name__)


async def save_feedback(feedback: Feedback) -> dict:
    data = feedback.model_dump(mode="json")
    device_id = data["device_id"]
    threshold_id = data["threshold_id"]
    logger.info(
        "Saving feedback for device %s on threshold %s", device_id, threshold_id
    )
    result = await feedback_collection.update_one(
        {"threshold_id": threshold_id}, {"$set": data}, upsert=True
    )
    if data.get("summary"):
        await ride_history_collection.update_one(
            {"device_id": device_id, "threshold_id": threshold_id},
            {"$set": {"feedback": data["summary"]}},
        )
    logger.debug(
        "Feedback upserted for threshold %s: modified=%s upserted_id=%s", threshold_id,
        getattr(result, "modified_count", None), getattr(result, "upserted_id", None)
    )
    return {
        "status": "ok",
        "device_id": device_id,
        "threshold_id": threshold_id,
        "modified_count": getattr(result, "modified_count", None),
        "upserted_id": str(getattr(result, "upserted_id", "")) or None,
    }


async def create_feedback_entry(device_id: str, threshold_id: str) -> None:
    """Create an empty ride feedback entry for a given threshold.

    This placeholder allows attaching user feedback at a later time while
    ensuring only one feedback document exists per threshold.
    """
    doc = {
        "device_id": device_id,
        "threshold_id": threshold_id,
        "created_at": datetime.now().isoformat(),
    }
    await feedback_collection.update_one(
        {"threshold_id": threshold_id}, {"$setOnInsert": doc}, upsert=True
    )
