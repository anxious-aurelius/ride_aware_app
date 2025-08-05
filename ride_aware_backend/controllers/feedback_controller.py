import logging
from models.feedback import Feedback
from services.db import feedback_collection

logger = logging.getLogger(__name__)


async def save_feedback(feedback: Feedback) -> dict:
    data = feedback.model_dump(mode="json")
    device_id = data["device_id"]
    logger.info("Saving feedback for device %s", device_id)
    result = await feedback_collection.insert_one(data)
    logger.debug(
        "Feedback inserted with id %s for device %s", result.inserted_id, device_id
    )
    return {"status": "ok", "feedback_id": str(result.inserted_id)}
