import asyncio
import logging
from datetime import datetime, timedelta
from fastapi import HTTPException
from pymongo.errors import PyMongoError
from models.ride_history import RideHistoryEntry
from services.db import ride_history_collection

logger = logging.getLogger(__name__)


async def create_history_entry(
    device_id: str, threshold_id: str, date: str, start_time: str, end_time: str
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
    }
    await ride_history_collection.update_one(
        {"threshold_id": threshold_id}, {"$setOnInsert": doc}, upsert=True
    )


async def save_ride(entry: RideHistoryEntry) -> dict:
    try:
        doc = entry.model_dump(mode="json")
        await ride_history_collection.update_one(
            {"device_id": entry.device_id, "threshold_id": entry.threshold_id},
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
    """Persist a ride to the database after a delay.

    This allows a ride to be submitted immediately while deferring the
    insertion so that it appears in ride history after ``delay_seconds``.
    """
    await asyncio.sleep(delay_seconds)
    await save_ride(entry)


async def fetch_rides(device_id: str, last_days: int = 30):
    since = datetime.utcnow().date() - timedelta(days=last_days)
    cursor = ride_history_collection.find(
        {"device_id": device_id, "date": {"$gte": since.isoformat()}}
    ).sort("date", -1)
    rides = []
    async for doc in cursor:
        doc.pop("_id", None)
        rides.append(RideHistoryEntry(**doc).model_dump(mode="json"))
    return rides
