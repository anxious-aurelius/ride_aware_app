from __future__ import annotations

import logging
from typing import List

from models.thresholds import WeatherLimits


logger = logging.getLogger(__name__)


def evaluate_thresholds(weather_data: dict, thresholds: WeatherLimits) -> List[str]:
    """Compare weather data against user thresholds.

    Returns a list of messages for each exceeded threshold."""
    messages: List[str] = []
    if (
        thresholds.max_wind_speed is not None
        and weather_data.get("wind_speed") is not None
        and weather_data["wind_speed"] > thresholds.max_wind_speed
    ):
        messages.append("Wind speed exceeds your comfort limit")

    rain = weather_data.get("rain") or 0
    if thresholds.max_rain_intensity is not None and rain > thresholds.max_rain_intensity:
        messages.append("Rain intensity exceeds your comfort limit")

    if (
        thresholds.max_humidity is not None
        and weather_data.get("humidity") is not None
        and weather_data["humidity"] > thresholds.max_humidity
    ):
        messages.append("Humidity exceeds your comfort limit")

    temp = weather_data.get("temp")
    if temp is not None:
        if thresholds.min_temperature is not None and temp < thresholds.min_temperature:
            messages.append("Temperature is below your comfort range")
        if thresholds.max_temperature is not None and temp > thresholds.max_temperature:
            messages.append("Temperature is above your comfort range")

    if (
        thresholds.min_visibility is not None
        and weather_data.get("visibility") is not None
        and weather_data["visibility"] < thresholds.min_visibility
    ):
        messages.append("Visibility is below your comfort limit")

    if (
        thresholds.max_uv_index is not None
        and weather_data.get("uvi") is not None
        and weather_data["uvi"] > thresholds.max_uv_index
    ):
        messages.append("UV index exceeds your comfort limit")

    pollution = weather_data.get("pollution")
    if (
        thresholds.max_pollution is not None
        and pollution is not None
        and pollution > thresholds.max_pollution
    ):
        messages.append("Pollution exceeds your comfort limit")

    logger.debug("Threshold evaluation messages: %s", messages)
    return messages

