from __future__ import annotations

import logging
from datetime import datetime
import os
from typing import Dict

import requests


class MissingAPIKeyError(Exception):
    """Raised when the OpenWeather API key is missing."""

OPENWEATHER_URL = os.getenv(
    "OPENWEATHER_URL", "https://api.openweathermap.org/data/2.5/forecast"
)
logger = logging.getLogger(__name__)


def get_hourly_forecast(lat: float, lon: float, target_time: datetime) -> Dict:

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
        "units": "metric",
        "cnt": 8,
    }
    response = requests.get(OPENWEATHER_URL, params=params)
    logger.debug(
        "Weather API response status: %s", getattr(response, "status_code", "unknown")
    )
    response.raise_for_status()
    forecast_list = response.json().get("list", [])
    if not forecast_list:
        logger.error("No forecast data available from weather service")
        raise ValueError("No forecast data available")

    target_ts = int(target_time.timestamp())
    closest = min(forecast_list, key=lambda h: abs(h.get("dt", 0) - target_ts))

    rain_data = closest.get("rain")
    if isinstance(rain_data, dict):
        rain_data = rain_data.get("3h")

    data = {
        "wind_speed": closest.get("wind", {}).get("speed"),
        "wind_deg": closest.get("wind", {}).get("deg"),
        "rain": rain_data,
        "humidity": closest.get("main", {}).get("humidity"),
        "temp": closest.get("main", {}).get("temp"),
        "visibility": closest.get("visibility"),
        "uvi": closest.get("uvi"),
        "clouds": closest.get("clouds", {}).get("all"),
    }
    logger.debug("Selected weather data: %s", data)
    return data


def get_next_hours_forecast(lat: float, lon: float, hours: int = 6):
    """Return forecast snapshots for the upcoming ``hours`` hours."""
    logger.info(
        "Fetching next %s hours forecast for lat=%s lon=%s", hours, lat, lon
    )
    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        logger.error("OPENWEATHER_API_KEY environment variable not set")
        raise MissingAPIKeyError("OPENWEATHER_API_KEY environment variable not set")

    params = {
        "lat": lat,
        "lon": lon,
        "appid": api_key,
        "units": "metric",
        "cnt": hours,
    }
    response = requests.get(OPENWEATHER_URL, params=params)
    logger.debug(
        "Weather API response status: %s", getattr(response, "status_code", "unknown")
    )
    response.raise_for_status()
    forecast_list = response.json().get("list", [])[:hours]
    results = []
    for item in forecast_list:
        rain_data = item.get("rain")
        if isinstance(rain_data, dict):
            rain_data = rain_data.get("3h") or rain_data.get("1h")
        results.append(
            {
                "time": datetime.fromtimestamp(item.get("dt", 0)).isoformat(),
                "wind_speed": item.get("wind", {}).get("speed"),
                "wind_deg": item.get("wind", {}).get("deg"),
                "rain": rain_data,
                "humidity": item.get("main", {}).get("humidity"),
                "temp": item.get("main", {}).get("temp"),
            }
        )
    logger.debug("Next hours forecast data: %s", results)
    return results

