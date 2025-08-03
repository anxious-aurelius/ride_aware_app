import logging

from fastapi import APIRouter, HTTPException
from controllers.commute_status_controller import get_status
from services.weather_service import MissingAPIKeyError


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/commute", tags=["commute"])


@router.get("/status/{device_id}")
async def commute_status(device_id: str):
    """Return commute status for the specified device."""
    logger.info("Requesting commute status for device %s", device_id)
    try:
        return await get_status(device_id)
    except ValueError as e:
        logger.warning("Thresholds not found for device %s: %s", device_id, e)
        raise HTTPException(status_code=404, detail=str(e))
    except MissingAPIKeyError as e:
        logger.error("Weather service configuration error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
    except Exception:
        logger.exception("Unexpected error retrieving commute status for %s", device_id)
        raise HTTPException(status_code=500, detail="Internal server error")


