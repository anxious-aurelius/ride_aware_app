import logging
from fastapi import HTTPException
from models.thresholds import Thresholds
from services.db import thresholds_collection


logger = logging.getLogger(__name__)


async def upsert_threshold(threshold: Thresholds) -> dict:
    data = threshold.model_dump(mode="json")
    device_id = data["device_id"]
    date = data["date"]
    start_time = data["start_time"]
    end_time = data["end_time"]
    logger.info(
        "Upserting thresholds for device %s on %s from %s to %s",
        device_id,
        date,
        start_time,
        end_time,
    )

    filter_doc = {
        "device_id": device_id,
        "date": date,
        "start_time": start_time,
        "end_time": end_time,
    }

    result = await thresholds_collection.update_one(
        filter_doc,
        {"$set": data},
        upsert=True,
    )
    logger.info(
        "Thresholds upserted for device %s on %s from %s to %s",
        device_id,
        date,
        start_time,
        end_time,
    )
    logger.debug(
        "Upsert result for %s: modified=%s upserted_id=%s",
        device_id,
        getattr(result, "modified_count", None),
        getattr(result, "upserted_id", None),
    )

    return {
        "device_id": device_id,
        "date": date,
        "start_time": start_time,
        "end_time": end_time,
        "status": "ok",
        "modified_count": getattr(result, "modified_count", None),
        "upserted_id": str(getattr(result, "upserted_id", "")) or None,
    }


async def get_thresholds(device_id: str, date: str, start_time: str, end_time: str) -> dict:
    logger.info(
        "Retrieving thresholds for device %s on %s from %s to %s",
        device_id,
        date,
        start_time,
        end_time,
    )
    doc = await thresholds_collection.find_one(
        {
            "device_id": device_id,
            "date": date,
            "start_time": start_time,
            "end_time": end_time,
        }
    )
    if not doc:
        logger.warning(
            "Thresholds not found for device %s on %s from %s to %s",
            device_id,
            date,
            start_time,
            end_time,
        )
        raise HTTPException(status_code=404, detail="Thresholds not found")

    # Remove _id and validate through model
    doc.pop("_id", None)
    return Thresholds(**doc).model_dump(mode="json")

