import logging
from fastapi import HTTPException
from models.thresholds import Thresholds
from services.db import thresholds_collection


logger = logging.getLogger(__name__)


async def upsert_threshold(threshold: Thresholds) -> dict:
    data = threshold.model_dump(mode="json")
    device_id = data["device_id"]
    logger.info("Upserting thresholds for device %s", device_id)

    result = await thresholds_collection.update_one(
        {"device_id": device_id},
        {"$set": data},
        upsert=True,
    )
    logger.info("Thresholds upserted for device %s", device_id)
    logger.debug(
        "Upsert result for %s: modified=%s upserted_id=%s",
        device_id,
        getattr(result, "modified_count", None),
        getattr(result, "upserted_id", None),
    )

    return {
        "device_id": device_id,
        "status": "ok",
        "modified_count": getattr(result, "modified_count", None),
        "upserted_id": str(getattr(result, "upserted_id", "")) or None,
    }


async def get_thresholds(device_id: str) -> dict:
    logger.info("Retrieving thresholds for device %s", device_id)
    doc = await thresholds_collection.find_one({"device_id": device_id})
    if not doc:
        logger.warning("Thresholds not found for device %s", device_id)
        raise HTTPException(status_code=404, detail="Thresholds not found")

    # Remove _id and validate through model
    doc.pop("_id", None)
    return Thresholds(**doc).model_dump(mode="json")

