from __future__ import annotations

import logging
from datetime import datetime

from models.thresholds import Thresholds
from services.commute_evaluator import evaluate_thresholds
from services.weather_service import get_hourly_forecast
from services.db import thresholds_collection
from utils.commute_window import parse_time


logger = logging.getLogger(__name__)


async def get_commute_status(device_id: str) -> dict:
    """Return commute status for morning and evening windows."""
    logger.info("Computing commute status for device %s", device_id)
    doc = await thresholds_collection.find_one({"device_id": device_id})
    if not doc:
        logger.warning("Thresholds not found for device %s", device_id)
        raise ValueError("Thresholds not found")
    doc.pop("_id", None)
    logger.debug("Thresholds document for %s: %s", device_id, doc)
    thresholds = Thresholds(**doc)

    lat = float(thresholds.office_location.latitude)
    lon = float(thresholds.office_location.longitude)

    today = datetime.now().date()
    if thresholds.commute_windows:
        morning_dt = datetime.combine(today, parse_time(thresholds.commute_windows.morning))
        evening_dt = datetime.combine(today, parse_time(thresholds.commute_windows.evening))
    else:
        morning_dt = datetime.combine(today, parse_time("08:00"))
        evening_dt = datetime.combine(today, parse_time("17:00"))

    morning_weather = get_hourly_forecast(lat, lon, morning_dt)
    evening_weather = get_hourly_forecast(lat, lon, evening_dt)
    logger.debug("Morning weather: %s, Evening weather: %s", morning_weather, evening_weather)

    limits_data = thresholds.weather_limits
    morning_exceeded = evaluate_thresholds(morning_weather, limits_data)
    evening_exceeded = evaluate_thresholds(evening_weather, limits_data)
    logger.info(
        "Commute evaluation for %s - morning exceeded: %s, evening exceeded: %s",
        device_id,
        morning_exceeded,
        evening_exceeded,
    )

    return {
        "device_id": device_id,
        "morning_status": {
            "exceeded": morning_exceeded,
            "weather_snapshot": morning_weather,
        },
        "evening_status": {
            "exceeded": evening_exceeded,
            "weather_snapshot": evening_weather,
        },
    }

