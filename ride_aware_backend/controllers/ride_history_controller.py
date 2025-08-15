# controllers/ride_history_controller.py
import asyncio
import logging
from datetime import datetime, timedelta
from fastapi import HTTPException
from pymongo.errors import PyMongoError
from bson import ObjectId
from models.ride_history import RideHistoryEntry
from services.db import ride_history_collection
from services.weather_history_service import (
    schedule_weather_collection,
    fetch_weather_history,
    fetch_weather_history_window,
)

logger = logging.getLogger(__name__)


def _serialize(obj):
    if isinstance(obj, ObjectId):
        return str(obj)
    if isinstance(obj, list):
        return [_serialize(item) for item in obj]
    if isinstance(obj, dict):
        return {k: _serialize(v) for k, v in obj.items()}
    return obj


async def create_history_entry(
    device_id: str,
    threshold_id: str,
    date: str,
    start_time: str,
    end_time: str,
    threshold_snapshot: dict,
) -> None:
    """Create an empty history record linked to a threshold."""
    doc = {
        "device_id": device_id,
        "threshold_id": threshold_id,
        "date": date,
        "start_time": start_time,
        "end_time": end_time,
        "status": "pending",
        "summary": {},
        "threshold": threshold_snapshot,
        "feedback": None,
    }
    await ride_history_collection.update_one(
        {
            "threshold_id": threshold_id,
            "date": date,
            "start_time": start_time,
        },
        {"$setOnInsert": doc},
        upsert=True,
    )
    await schedule_weather_collection(
        device_id,
        threshold_id,
        date,
        start_time,
        end_time,
        timezone_str=threshold_snapshot.get("timezone"),
        interval_minutes=threshold_snapshot.get("weather_snapshot_interval_minutes", 10),
    )


async def save_ride(entry: RideHistoryEntry) -> dict:
    try:
        doc = entry.model_dump(mode="json")
        await ride_history_collection.update_one(
            {
                "device_id": entry.device_id,
                "threshold_id": entry.threshold_id,
                "date": entry.date.isoformat(),
                "start_time": entry.start_time,
            },
            {"$set": doc},
            upsert=True,
        )
        logger.info(
            "Ride history saved for device %s on %s (threshold %s)",
            entry.device_id,
            entry.date,
            entry.threshold_id,
        )
        return {"status": "ok"}
    except PyMongoError as e:
        logger.error(
            "Database error saving ride history for %s: %s", entry.device_id, e
        )
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


async def save_ride_after_delay(entry: RideHistoryEntry, delay_seconds: int = 60) -> None:
    await asyncio.sleep(delay_seconds)
    await save_ride(entry)


async def fetch_rides(device_id: str, last_days: int = 30):
    since = datetime.now().date() - timedelta(days=last_days)
    cursor = (
        ride_history_collection.find(
            {"device_id": device_id, "date": {"$gte": since.isoformat()}}
        )
        .sort([("date", -1), ("start_time", -1)])
    )
    rides = []
    async for doc in cursor:
        threshold_id = str(doc.get("threshold_id"))
        date_str = doc.get("date")
        start_time = doc.get("start_time")
        end_time = doc.get("end_time")
        timezone_str = (doc.get("threshold") or {}).get("timezone")

        doc.pop("_id", None)

        # Prefer snapshots strictly inside the window; if empty, fall back to all.
        try:
            history = await fetch_weather_history_window(
                threshold_id=threshold_id,
                date_str=date_str,
                start_time=start_time,
                end_time=end_time,
                timezone_str=timezone_str,
            )
        except Exception as e:
            logger.warning("window fetch failed for %s: %s", threshold_id, e)
            history = []

        if not history:
            history = await fetch_weather_history(threshold_id)

        doc["weather_history"] = history
        doc = _serialize(doc)
        rides.append(RideHistoryEntry(**doc).model_dump(mode="json"))
    return rides
