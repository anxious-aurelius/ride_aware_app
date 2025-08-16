from __future__ import annotations

import logging
from typing import List, Dict
import math

from models.thresholds import WeatherLimits


logger = logging.getLogger(__name__)


def evaluate_thresholds(weather_data: dict, thresholds: WeatherLimits) -> List[str]:
    return evaluate_detailed_thresholds(weather_data, thresholds)["issues"]


def evaluate_detailed_thresholds(
    weather_data: Dict, thresholds: WeatherLimits, route_bearing: float | None = None
) -> Dict[str, List[str] | float | None]:
    issues: List[str] = []
    borderline: List[str] = []

    wind = float(weather_data.get("wind_speed") or 0)
    rain = float(weather_data.get("rain") or 0)
    humidity = float(weather_data.get("humidity") or 0)
    temp = weather_data.get("temp")
    wind_deg = weather_data.get("wind_deg")

    max_wind_speed = (
        float(thresholds.max_wind_speed) if thresholds.max_wind_speed is not None else None
    )
    max_rain_intensity = (
        float(thresholds.max_rain_intensity)
        if thresholds.max_rain_intensity is not None
        else None
    )
    max_humidity = (
        float(thresholds.max_humidity) if thresholds.max_humidity is not None else None
    )
    min_temperature = (
        float(thresholds.min_temperature)
        if thresholds.min_temperature is not None
        else None
    )
    max_temperature = (
        float(thresholds.max_temperature)
        if thresholds.max_temperature is not None
        else None
    )
    headwind_sens = (
        float(thresholds.headwind_sensitivity)
        if thresholds.headwind_sensitivity is not None
        else None
    )
    crosswind_sens = (
        float(thresholds.crosswind_sensitivity)
        if thresholds.crosswind_sensitivity is not None
        else None
    )

    min_visibility = (
        float(thresholds.min_visibility)
        if thresholds.min_visibility is not None
        else None
    )
    max_uv_index = (
        float(thresholds.max_uv_index) if thresholds.max_uv_index is not None else None
    )
    max_pollution = (
        float(thresholds.max_pollution)
        if thresholds.max_pollution is not None
        else None
    )

    if max_wind_speed is not None:
        if wind > max_wind_speed:
            issues.append("Wind speed exceeds your comfort limit")
        elif wind > max_wind_speed * 0.8:
            borderline.append("Wind speed near limit")

    if max_rain_intensity is not None:
        if rain > max_rain_intensity:
            issues.append("Rain intensity exceeds your comfort limit")
        elif rain > max_rain_intensity * 0.8:
            borderline.append("Rain near limit")

    if max_humidity is not None and humidity > max_humidity:
        issues.append("Humidity exceeds your comfort limit")

    if temp is not None:
        temp = float(temp)
        if min_temperature is not None and temp < min_temperature:
            issues.append("Temperature is below your comfort range")
        elif min_temperature is not None and temp < min_temperature + 2:
            borderline.append("Temperature near limit")
        if max_temperature is not None and temp > max_temperature:
            issues.append("Temperature is above your comfort range")
        elif max_temperature is not None and temp > max_temperature - 2:
            if "Temperature near limit" not in borderline:
                borderline.append("Temperature near limit")

    if (
        min_visibility is not None
        and weather_data.get("visibility") is not None
        and weather_data["visibility"] < min_visibility
    ):
        issues.append("Visibility is below your comfort limit")

    if (
        max_uv_index is not None
        and weather_data.get("uvi") is not None
        and weather_data["uvi"] > max_uv_index
    ):
        issues.append("UV index exceeds your comfort limit")

    pollution = weather_data.get("pollution")
    if max_pollution is not None and pollution is not None and pollution > max_pollution:
        issues.append("Pollution exceeds your comfort limit")

    head = cross = None
    if wind_deg is not None and route_bearing is not None:
        rel = ((float(wind_deg) - route_bearing) + 360) % 360
        head = wind * math.cos(math.radians(rel))
        cross = wind * math.sin(math.radians(rel))

        if headwind_sens is not None:
            if abs(head) > headwind_sens:
                issues.append("Headwind exceeds your comfort limit")
            elif abs(head) > headwind_sens * 0.8:
                borderline.append("Headwind near limit")

        if crosswind_sens is not None:
            if abs(cross) > crosswind_sens:
                issues.append("Crosswind exceeds your comfort limit")
            elif abs(cross) > crosswind_sens * 0.8:
                borderline.append("Crosswind near limit")

    logger.debug("Detailed threshold evaluation issues=%s borderline=%s", issues, borderline)
    return {
        "issues": issues,
        "borderline": borderline,
        "headwind": abs(head) if head is not None else None,
        "crosswind": abs(cross) if cross is not None else None,
    }

