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
    """Return commute status for route start and end windows."""
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
    start_dt = datetime.combine(today, parse_time(thresholds.start_time))
    end_dt = datetime.combine(today, parse_time(thresholds.end_time))

    start_weather = get_hourly_forecast(lat, lon, start_dt)
    end_weather = get_hourly_forecast(lat, lon, end_dt)
    logger.debug(
        "Start weather: %s, End weather: %s", start_weather, end_weather
    )

    limits_data = thresholds.weather_limits
    start_exceeded = evaluate_thresholds(start_weather, limits_data)
    end_exceeded = evaluate_thresholds(end_weather, limits_data)
    logger.info(
        "Commute evaluation for %s - start exceeded: %s, end exceeded: %s",
        device_id,
        start_exceeded,
        end_exceeded,
    )

    return {
        "device_id": device_id,
        "start_status": {
            "exceeded": start_exceeded,
            "weather_snapshot": start_weather,
        },
        "end_status": {
            "exceeded": end_exceeded,
            "weather_snapshot": end_weather,
        },
    }

