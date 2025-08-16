import logging
from datetime import datetime
from typing import List, Dict
from services.weather_service import (
    get_hourly_forecast,
    get_next_hours_forecast,
)
from services.route_weather_service import evaluate_route_weather
from services.forecast_cache_service import save_hourly_forecasts
from models.thresholds import WeatherLimits

logger = logging.getLogger(__name__)

async def get_forecast(lat: float, lon: float, time: datetime) -> dict:
    logger.info("Getting forecast for lat=%s lon=%s at %s", lat, lon, time)
    return get_hourly_forecast(lat, lon, time)


async def get_next_hours(lat: float, lon: float, hours: int) -> list:
    logger.info(
        "Controller retrieving next %s hours forecast for lat=%s lon=%s",
        hours,
        lat,
        lon,
    )
    data = get_next_hours_forecast(lat, lon, hours)
    await save_hourly_forecasts(lat, lon, data)
    return data


async def evaluate_route(
    points: List[Dict[str, float]], time: datetime, thresholds: WeatherLimits
) -> dict:
    logger.info("Evaluating route with %s points at %s", len(points), time)
    return evaluate_route_weather(points, time, thresholds)
