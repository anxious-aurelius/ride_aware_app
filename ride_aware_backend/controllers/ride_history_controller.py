import logging
from datetime import datetime, timedelta
from fastapi import HTTPException
from pymongo.errors import PyMongoError
from models.ride_history import RideHistoryEntry
from services.db import ride_history_collection

logger = logging.getLogger(__name__)

async def save_ride(entry: RideHistoryEntry) -> dict:
    try:
        await ride_history_collection.insert_one(entry.model_dump(mode="json"))
        logger.info("Ride history saved for device %s on %s", entry.device_id, entry.date)
        return {"status": "ok"}
    except PyMongoError as e:
        logger.error("Database error saving ride history for %s: %s", entry.device_id, e)
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

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
