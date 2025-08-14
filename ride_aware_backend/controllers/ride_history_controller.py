# controllers/ride_history_controller.py

import asyncio
import logging
from datetime import datetime, timedelta, date
from fastapi import HTTPException
from pymongo.errors import PyMongoError
from bson import ObjectId

from models.ride_history import RideHistoryEntry
from services.db import ride_history_collection, weather_history_collection
from services.weather_history_service import (
    schedule_weather_collection,
    fetch_weather_history,
)
from utils.commute_window import parse_time
from zoneinfo import ZoneInfo

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
    """Create an empty history record linked to a threshold and schedule snapshots."""
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
        interval_minutes=threshold_snapshot.get(
            "weather_snapshot_interval_minutes", 10
        ),
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


async def save_ride_after_delay(
    entry: RideHistoryEntry, delay_seconds: int = 60
) -> None:
    """Persist a ride to the database after a small delay."""
    await asyncio.sleep(delay_seconds)
    await save_ride(entry)


# ---------- NEW: robust fallback join by time window ----------

async def _fallback_weather_by_window(doc: dict) -> list[dict]:
    """
    If no snapshots match the exact threshold_id, fall back to time-window join:
      device_id + [start_dt, end_dt] in the ride's timezone.
    """
    try:
        thr = (doc.get("threshold") or {})
        tzname = thr.get("timezone")
        tz = ZoneInfo(tzname) if tzname else ZoneInfo(datetime.now().astimezone().tzinfo.key)

        ride_date = date.fromisoformat(doc["date"])
        start_dt = datetime.combine(ride_date, parse_time(doc["start_time"]), tzinfo=tz)
        end_dt = datetime.combine(ride_date, parse_time(doc["end_time"]), tzinfo=tz)

        cursor = weather_history_collection.find(
            {
                "device_id": doc["device_id"],
                "timestamp": {"$gte": start_dt, "$lte": end_dt},
            }
        ).sort("timestamp", 1)

        out: list[dict] = []
        async for w in cursor:
            w.pop("_id", None)
            out.append(_serialize(w))
        if out:
            logger.info(
                "Fallback weather join returned %d snapshots for device %s on %s %s–%s",
                len(out), doc["device_id"], doc["date"], doc["start_time"], doc["end_time"]
            )
        return out
    except Exception as e:
        logger.warning("Fallback weather join failed: %s", e)
        return []


async def fetch_rides(device_id: str, last_days: int = 30):
    """
    Return recent rides with weather_history.
    Priority:
      1) Join snapshots by exact threshold_id.
      2) If none, fall back to device_id + time-window join.
    """
    since = datetime.now().date() - timedelta(days=last_days)
    cursor = ride_history_collection.find(
        {"device_id": device_id, "date": {"$gte": since.isoformat()}}
    ).sort([("date", -1), ("start_time", -1)])

    rides = []
    async for doc in cursor:
        tid = doc.get("threshold_id")
        history: list[dict] = []

        # Primary: exact threshold_id
        if tid:
            history = await fetch_weather_history(tid)

        # Fallback if empty
        if not history:
            logger.debug(
                "No snapshots for threshold_id=%s; trying time-window fallback", tid
            )
            history = await _fallback_weather_by_window(doc)

        doc["weather_history"] = history
        doc.pop("_id", None)
        ser = _serialize(doc)

        # Try strict model validation first; if it fails, return the serialized dict
        try:
            rides.append(RideHistoryEntry(**ser).model_dump(mode="json"))
        except Exception as e:
            logger.error("Ride document failed model validation: %s; doc=%s", e, ser)
            rides.append(ser)

    return rides
