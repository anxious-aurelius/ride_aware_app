import logging
from fastapi import HTTPException
from models.thresholds import Thresholds
from services.db import thresholds_collection
from controllers.feedback_controller import create_feedback_entry
from controllers.ride_history_controller import create_history_entry
from services.alert_service import schedule_pre_route_alert


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

    existing = await thresholds_collection.find_one(filter_doc)
    if existing:
        threshold_id = existing.get("_id")
        result = await thresholds_collection.update_one(
            {"_id": threshold_id}, {"$set": data}
        )
    else:
        insert_result = await thresholds_collection.insert_one(data)
        threshold_id = insert_result.inserted_id
        result = insert_result

    threshold_id_str = str(threshold_id)
    await create_feedback_entry(device_id, threshold_id_str)
    await create_history_entry(
        device_id, threshold_id_str, date, start_time, end_time
    )
    await schedule_pre_route_alert(threshold)

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
        "threshold_id": threshold_id_str,
        "status": "ok",
        "modified_count": getattr(result, "modified_count", None),
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

