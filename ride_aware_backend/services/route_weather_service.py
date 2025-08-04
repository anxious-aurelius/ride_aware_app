from __future__ import annotations

import logging
from datetime import datetime
from typing import List, Dict, Any

from models.thresholds import WeatherLimits
from services.weather_service import get_hourly_forecast
from services.commute_evaluator import evaluate_detailed_thresholds

logger = logging.getLogger(__name__)


def _bearing(a: Dict[str, float], b: Dict[str, float]) -> float:
    """Calculate bearing from point a to b in degrees."""
    import math

    lat1 = math.radians(a["latitude"])
    lat2 = math.radians(b["latitude"])
    dlon = math.radians(b["longitude"] - a["longitude"])
    y = math.sin(dlon) * math.cos(lat2)
    x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dlon)
    brng = math.degrees(math.atan2(y, x))
    return (brng + 360) % 360


def evaluate_route_weather(
    points: List[Dict[str, float]], time: datetime, thresholds: WeatherLimits
) -> Dict[str, Any]:
    """Fetch weather for multiple route points and evaluate against thresholds.

    Parameters
    ----------
    points: list of dict
        Sequence of coordinates with keys ``latitude`` and ``longitude``.
    time: datetime
        Scheduled commute time.
    thresholds: WeatherLimits
        User-defined comfort limits.
    """
    if not points:
        raise ValueError("At least one route point is required")

    route_bearing = _bearing(points[0], points[-1]) if len(points) > 1 else None
    results: List[Dict[str, Any]] = []
    overall_issues: set[str] = set()
    overall_borderline: set[str] = set()

    max_values: Dict[str, float] = {
        "wind_speed": 0.0,
        "rain": 0.0,
        "humidity": 0.0,
        "headwind": 0.0,
        "crosswind": 0.0,
        "temp_max": float("-inf"),
        "temp_min": float("inf"),
    }

    for idx, pt in enumerate(points):
        logger.debug("Fetching weather for point %s: %s", idx, pt)
        weather = get_hourly_forecast(pt["latitude"], pt["longitude"], time)
        detailed = evaluate_detailed_thresholds(weather, thresholds, route_bearing)

        # Track maxima/minima for summary
        wind = weather.get("wind_speed") or 0
        rain = weather.get("rain") or 0
        humidity = weather.get("humidity") or 0
        temp = weather.get("temp")
        head = detailed.get("headwind") or 0
        cross = detailed.get("crosswind") or 0

        max_values["wind_speed"] = max(max_values["wind_speed"], wind)
        max_values["rain"] = max(max_values["rain"], rain)
        max_values["humidity"] = max(max_values["humidity"], humidity)
        max_values["headwind"] = max(max_values["headwind"], head)
        max_values["crosswind"] = max(max_values["crosswind"], cross)
        if temp is not None:
            max_values["temp_max"] = max(max_values["temp_max"], temp)
            max_values["temp_min"] = min(max_values["temp_min"], temp)

        overall_issues.update(detailed["issues"])
        overall_borderline.update(detailed["borderline"])

        results.append(
            {
                "index": idx,
                "location": pt,
                "weather": weather,
                "issues": detailed["issues"],
                "borderline": detailed["borderline"],
                "headwind": detailed["headwind"],
                "crosswind": detailed["crosswind"],
            }
        )

    status = "alert" if overall_issues else ("warning" if overall_borderline else "ok")
    summary = {
        "max_wind_speed": max_values["wind_speed"],
        "max_rain": max_values["rain"],
        "max_humidity": max_values["humidity"],
        "max_headwind": max_values["headwind"],
        "max_crosswind": max_values["crosswind"],
        "min_temp": max_values["temp_min"],
        "max_temp": max_values["temp_max"],
    }

    return {
        "status": status,
        "issues": list(overall_issues),
        "borderline": list(overall_borderline),
        "summary": summary,
        "points": results,
    }
