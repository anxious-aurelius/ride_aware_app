# routes/ride_history.py
import logging
from fastapi import APIRouter, HTTPException, Query
from controllers.ride_history_controller import fetch_rides

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/rideHistory")
async def get_history(device_id: str, lastDays: int = Query(30, ge=1, le=365)):
    logger.info("Fetching ride history for device %s", device_id)
    try:
        return await fetch_rides(device_id, last_days=lastDays)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("get_history failed: %s", e)
        raise HTTPException(status_code=500, detail="Internal Server Error")
