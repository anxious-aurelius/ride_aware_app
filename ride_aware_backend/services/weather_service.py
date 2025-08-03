from __future__ import annotations

import logging
from datetime import datetime
import os
from typing import Dict

import requests


class MissingAPIKeyError(Exception):
    """Raised when the OpenWeather API key is missing."""

OPENWEATHER_URL = os.getenv(
    "OPENWEATHER_URL", "https://api.openweathermap.org/data/2.5/onecall"
)
logger = logging.getLogger(__name__)


def get_hourly_forecast(lat: float, lon: float, target_time: datetime) -> Dict:
    """Fetch hourly forecast and return data closest to ``target_time``.

    Parameters
    ----------
    lat, lon: float
        Coordinates for the forecast request.
    target_time: datetime
        Desired hour for the weather forecast.

    Returns
    -------
    dict
        Dictionary containing key weather metrics for the closest hour.
    """
    logger.info(
        "Fetching weather forecast for lat=%s lon=%s at %s",
        lat,
        lon,
        target_time,
    )
    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        logger.error("OPENWEATHER_API_KEY environment variable not set")
        raise MissingAPIKeyError("OPENWEATHER_API_KEY environment variable not set")

    params = {
        "lat": lat,
        "lon": lon,
        "appid": api_key,
        "exclude": "current,minutely,daily,alerts",
    }
    response = requests.get(OPENWEATHER_URL, params=params)
    logger.debug(
        "Weather API response status: %s", getattr(response, "status_code", "unknown")
    )
    response.raise_for_status()
    hourly = response.json().get("hourly", [])
    if not hourly:
        logger.error("No hourly data available from weather service")
        raise ValueError("No hourly data available")

    target_ts = int(target_time.timestamp())
    closest = min(hourly, key=lambda h: abs(h.get("dt", 0) - target_ts))

    data = {
        "wind_speed": closest.get("wind_speed"),
        "wind_deg": closest.get("wind_deg"),
        "rain": (
            closest.get("rain", {}).get("1h")
            if isinstance(closest.get("rain"), dict)
            else closest.get("rain")
        ),
        "humidity": closest.get("humidity"),
        "temp": closest.get("temp"),
        "visibility": closest.get("visibility"),
        "uvi": closest.get("uvi"),
        "clouds": closest.get("clouds"),
    }
    logger.debug("Selected weather data: %s", data)
    return data

