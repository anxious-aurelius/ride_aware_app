import logging
from typing import List
from fastapi import APIRouter, Query
from models.ride_history import RideHistoryEntry
from controllers.ride_history_controller import save_ride, fetch_rides

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/rideHistory", tags=["Ride History"])

@router.post("", include_in_schema=False)
@router.post("/")
async def submit_ride(entry: RideHistoryEntry):
    logger.info("Received ride history for device %s", entry.device_id)
    return await save_ride(entry)

@router.get("")
async def get_history(device_id: str, lastDays: int = Query(30, alias="lastDays")) -> List[RideHistoryEntry]:
    logger.info("Fetching ride history for device %s", device_id)
    rides = await fetch_rides(device_id, last_days=lastDays)
    return rides
