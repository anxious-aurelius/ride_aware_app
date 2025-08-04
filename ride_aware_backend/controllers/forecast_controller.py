import logging
from datetime import datetime
from typing import List, Dict
from services.weather_service import get_hourly_forecast
from services.route_weather_service import evaluate_route_weather
from models.thresholds import WeatherLimits

logger = logging.getLogger(__name__)

async def get_forecast(lat: float, lon: float, time: datetime) -> dict:
    """Controller layer for single forecast snapshot."""
    logger.info("Getting forecast for lat=%s lon=%s at %s", lat, lon, time)
    return get_hourly_forecast(lat, lon, time)


async def evaluate_route(
    points: List[Dict[str, float]], time: datetime, thresholds: WeatherLimits
) -> dict:
    """Controller layer for route-wide weather evaluation."""
    logger.info("Evaluating route with %s points at %s", len(points), time)
    return evaluate_route_weather(points, time, thresholds)
