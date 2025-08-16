# controllers/thresholds_controller.py
import logging
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from fastapi import HTTPException
from models.thresholds import Thresholds
from services.db import thresholds_collection
from controllers.feedback_controller import create_feedback_entry
from controllers.ride_history_controller import create_history_entry
from services.alert_service import schedule_pre_route_alert, schedule_feedback_reminder

logger = logging.getLogger(__name__)


async def upsert_threshold(threshold: Thresholds) -> dict:
    data = threshold.model_dump(mode="json")
    device_id = data["device_id"]
    date = data["date"]
    start_time = data["start_time"]
    end_time = data["end_time"]

    filter_doc = {
        "device_id": device_id,
        "date": date,
        "start_time": start_time,
        "end_time": end_time,
    }

    existing = await thresholds_collection.find_one(filter_doc)
    if existing:
        threshold_id = existing.get("_id")
        await thresholds_collection.update_one({"_id": threshold_id}, {"$set": data})
    else:
        insert_result = await thresholds_collection.insert_one(data)
        threshold_id = insert_result.inserted_id

    threshold_id_str = str(threshold_id)

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


async def get_thresholds(device_id: str, date: str, start_time: str, end_time: str) -> dict:
    doc = await thresholds_collection.find_one(
        {"device_id": device_id, "date": date, "start_time": start_time, "end_time": end_time}
    )
    if not doc:
        raise HTTPException(status_code=404, detail="Thresholds not found")
    doc.pop("_id", None)
    return Thresholds(**doc).model_dump(mode="json")


async def get_current_threshold(device_id: str) -> dict:
    today_server = datetime.now().date().isoformat()
    doc = await thresholds_collection.find_one({"device_id": device_id, "date": today_server})
    if not doc:
        cursor = (
            thresholds_collection.find({"device_id": device_id})
            .sort([("date", -1), ("start_time", -1)])
            .limit(1)
        )
        latest_docs = await cursor.to_list(1)
        latest = latest_docs[0] if latest_docs else None
        if not latest:
            raise HTTPException(status_code=404, detail="Thresholds not found")
        local_tz = datetime.now().astimezone().tzinfo
        tz_name = latest.get("timezone") or getattr(local_tz, "key", local_tz.tzname(None))
        try:
            tz = ZoneInfo(tz_name)
        except ZoneInfoNotFoundError:
            tz = local_tz
        now = datetime.now(tz)
        today_local = now.date().isoformat()
        if today_local != today_server:
            doc = await thresholds_collection.find_one({"device_id": device_id, "date": today_local})
        if not doc:
            doc = latest
    threshold_id = str(doc.pop("_id"))
    payload = Thresholds(**doc).model_dump(mode="json")
    payload["threshold_id"] = threshold_id
    return payload
