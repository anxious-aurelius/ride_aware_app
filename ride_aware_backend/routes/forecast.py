import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException
from controllers.forecast_controller import get_forecast
from services.weather_service import MissingAPIKeyError

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["Forecast"])

@router.get("/forecast")
async def forecast(lat: float, lon: float, time: datetime):
    """Return weather forecast snapshot for given coordinates and time."""
    logger.info("Requesting forecast for lat=%s lon=%s at %s", lat, lon, time)
    try:
        return await get_forecast(lat, lon, time)
    except MissingAPIKeyError as e:
        logger.error("Weather service configuration error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
    except Exception:
        logger.exception("Unexpected error retrieving forecast")
        raise HTTPException(status_code=500, detail="Internal server error")
