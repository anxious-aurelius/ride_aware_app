import logging
from datetime import datetime
from services.weather_service import get_hourly_forecast

logger = logging.getLogger(__name__)

async def get_forecast(lat: float, lon: float, time: datetime) -> dict:
    """Controller layer for single forecast snapshot."""
    logger.info("Getting forecast for lat=%s lon=%s at %s", lat, lon, time)
    return get_hourly_forecast(lat, lon, time)
