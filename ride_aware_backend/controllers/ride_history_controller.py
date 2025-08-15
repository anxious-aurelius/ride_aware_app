# controllers/ride_history_controller.py
import asyncio
import logging
from datetime import datetime, timedelta, date as date_cls
from fastapi import HTTPException
from pymongo.errors import PyMongoError
from bson import ObjectId
from zoneinfo import ZoneInfo

from models.ride_history import RideHistoryEntry
from services.db import ride_history_collection
from services.weather_history_service import (
    schedule_weather_collection,
    fetch_weather_history,
    fetch_weather_history_window,
)
from utils.commute_window import parse_time

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
    """Create an empty history record linked to a threshold and schedule/backfill weather snapshots."""
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
        {"threshold_id": threshold_id, "date": date, "start_time": start_time},
        {"$setOnInsert": doc},
        upsert=True,
    )

    await schedule_weather_collection(
        device_id=device_id,
        threshold_id=threshold_id,
        date_str=date,
        start_time=start_time,
        end_time=end_time,
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
        logger.error("Database error saving ride history for %s: %s", entry.device_id, e)
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


async def save_ride_after_delay(entry: RideHistoryEntry, delay_seconds: int = 60) -> None:
    await asyncio.sleep(delay_seconds)
    await save_ride(entry)


async def fetch_rides(device_id: str, last_days: int = 30):
    """Return recent rides for this device, with windowed weather history attached."""
    since = datetime.now().date() - timedelta(days=last_days)
    cursor = ride_history_collection.find(
        {"device_id": device_id, "date": {"$gte": since.isoformat()}}
    ).sort([("date", -1), ("start_time", -1)])

    rides = []
    async for doc in cursor:
        doc.pop("_id", None)

        threshold_snap = (doc.get("threshold") or {})
        tz_name = threshold_snap.get("timezone")
        try:
            tz = ZoneInfo(tz_name) if tz_name else datetime.now().astimezone().tzinfo
        except Exception:
            tz = datetime.now().astimezone().tzinfo

        try:
            ride_date = date_cls.fromisoformat(doc["date"])
            start_dt = datetime.combine(ride_date, parse_time(doc["start_time"]), tzinfo=tz)
            end_dt = datetime.combine(ride_date, parse_time(doc["end_time"]), tzinfo=tz)
        except Exception as e:
            logger.warning("Could not parse window for threshold %s: %s", doc.get("threshold_id"), e)
            start_dt = end_dt = None

        history = []
        try:
            if start_dt and end_dt and end_dt >= start_dt:
                history = await fetch_weather_history_window(doc["threshold_id"], start_dt, end_dt)
            if not history:
                history = await fetch_weather_history(doc["threshold_id"])
        except Exception as e:
            logger.warning("Weather history fetch failed for %s: %s", doc.get("threshold_id"), e)
            history = []

        doc["weather_history"] = history
        doc = _serialize(doc)
        rides.append(RideHistoryEntry(**doc).model_dump(mode="json"))

    return rides
