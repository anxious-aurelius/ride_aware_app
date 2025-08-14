import logging
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from fastapi import HTTPException

from models.thresholds import Thresholds
from services.db import thresholds_collection
from controllers.feedback_controller import create_feedback_entry
from controllers.ride_history_controller import create_history_entry
from services.alert_service import (
    schedule_pre_route_alert,
    schedule_feedback_reminder,
)

logger = logging.getLogger(__name__)


async def upsert_threshold(threshold: Thresholds) -> dict:
    """
    One document per (device_id, date). This keeps a stable threshold_id for a day,
    so weather_history joins by threshold_id work reliably.
    """
    data = threshold.model_dump(mode="json")
    device_id = data["device_id"]
    date = data["date"]
    start_time = data["start_time"]
    end_time = data["end_time"]

    # single doc per day
    filter_doc = {"device_id": device_id, "date": date}

    existing = await thresholds_collection.find_one(filter_doc)
    if existing:
        threshold_id = existing.get("_id")
        # update full snapshot but keep _id (stable across the day)
        await thresholds_collection.update_one({"_id": threshold_id}, {"$set": data})
    else:
        insert_result = await thresholds_collection.insert_one(data)
        threshold_id = insert_result.inserted_id

    threshold_id_str = str(threshold_id)

    # make sure related records/schedulers are in place
    await create_feedback_entry(device_id, threshold_id_str)
    await create_history_entry(device_id, threshold_id_str, date, start_time, end_time, data)
    await schedule_pre_route_alert(threshold)
    await schedule_feedback_reminder(threshold)

    return {
        "device_id": device_id,
        "date": date,
        "start_time": start_time,
        "end_time": end_time,
        "threshold_id": threshold_id_str,
        "status": "ok",
    }


async def get_thresholds(device_id: str, date: str, start_time: str | None = None, end_time: str | None = None) -> dict:
    """
    Fetch thresholds for a device on a specific date.
    start_time/end_time are accepted for backward compatibility but not required
    because we store a single record per (device_id, date).
    """
    logger.info("Retrieving thresholds for device %s on %s", device_id, date)

    doc = await thresholds_collection.find_one({"device_id": device_id, "date": date})
    if not doc:
        logger.warning("Thresholds not found for device %s on %s", device_id, date)
        raise HTTPException(status_code=404, detail="Thresholds not found")

    threshold_id = str(doc.pop("_id"))
    payload = Thresholds(**doc).model_dump(mode="json")
    payload["threshold_id"] = threshold_id
    return payload


async def get_current_threshold(device_id: str) -> dict:
    """
    Return today's thresholds for a device.
    If there is no record for server's today, we look at the latest record,
    infer its timezone, convert server 'now' into that tz, and try again for that local date.
    Finally we fall back to the latest record if still no exact match.
    """
    today_server = datetime.now().date().isoformat()

    # exact server day first
    doc = await thresholds_collection.find_one({"device_id": device_id, "date": today_server})
    if not doc:
        # latest doc for device
        cursor = (
            thresholds_collection.find({"device_id": device_id})
            .sort([("date", -1)])
            .limit(1)
        )
        latest_list = await cursor.to_list(length=1)
        latest = latest_list[0] if latest_list else None
        if not latest:
            raise HTTPException(status_code=404, detail="Thresholds not found")

        # infer timezone from latest record (or system tz as fallback)
        tz_name = latest.get("timezone")
        local_tz = datetime.now().astimezone().tzinfo
        if not tz_name and hasattr(local_tz, "key"):
            tz_name = getattr(local_tz, "key", None) or local_tz.tzname(None)

        try:
            tz = ZoneInfo(tz_name) if tz_name else local_tz
        except ZoneInfoNotFoundError:
            tz = local_tz

        # compute today's date in that tz and try again
        now_local = datetime.now().astimezone(tz)
        today_local = now_local.date().isoformat()
        doc = await thresholds_collection.find_one({"device_id": device_id, "date": today_local})
        if not doc:
            # final fallback: latest snapshot
            doc = latest

    threshold_id = str(doc.pop("_id"))
    payload = Thresholds(**doc).model_dump(mode="json")
    payload["threshold_id"] = threshold_id
    return payload
