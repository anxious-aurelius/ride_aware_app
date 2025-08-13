from __future__ import annotations

import asyncio
import logging
from datetime import datetime, date, timedelta
from typing import List, Dict

from models.weather_history import RouteWeatherSnapshot
from services.db import weather_history_collection, routes_collection
from services.weather_service import get_hourly_forecast
from utils.commute_window import parse_time

logger = logging.getLogger(__name__)


def _haversine(a: Dict[str, float], b: Dict[str, float]) -> float:
    """Return distance in km between two lat/lon points."""
    import math

    lat1 = math.radians(float(a["latitude"]))
    lon1 = math.radians(float(a["longitude"]))
    lat2 = math.radians(float(b["latitude"]))
    lon2 = math.radians(float(b["longitude"]))
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def _route_distance(points: List[Dict[str, float]]) -> float:
    dist = 0.0
    for i in range(len(points) - 1):
        dist += _haversine(points[i], points[i + 1])
    return dist


def calculate_interval(start_time: str, end_time: str, distance_km: float) -> int:
    """Return interval seconds for 1 km segments."""
    today = date.today()
    start_dt = datetime.combine(today, parse_time(start_time))
    end_dt = datetime.combine(today, parse_time(end_time))
    total = (end_dt - start_dt).total_seconds()
    if distance_km <= 0:
        return int(total)
    return max(1, int(total / distance_km))


async def _record_snapshot(device_id: str, threshold_id: str, lat: float, lon: float) -> None:
    weather = get_hourly_forecast(lat, lon, datetime.utcnow())
    snap = RouteWeatherSnapshot(
        device_id=device_id,
        threshold_id=threshold_id,
        timestamp=datetime.utcnow(),
        weather=weather,
    )
    await weather_history_collection.insert_one(snap.model_dump(mode="json"))


async def schedule_weather_collection(
    device_id: str,
    threshold_id: str,
    date_str: str,
    start_time: str,
    end_time: str,
) -> None:
    """Periodically record weather for the user's route."""
    route_doc = await routes_collection.find_one({"device_id": device_id})
    if not route_doc:
        logger.info("No route for %s; skipping weather collection", device_id)
        return

    points: List[Dict[str, float]] = route_doc.get("route_points") or []
    if not points:
        logger.info("Route %s has no points; skipping", device_id)
        return

    dist = _route_distance(points)
    interval = calculate_interval(start_time, end_time, dist)
    lat = float(points[0]["latitude"])
    lon = float(points[0]["longitude"])

    threshold_date = date.fromisoformat(date_str)
    start_dt = datetime.combine(threshold_date, parse_time(start_time))
    end_dt = datetime.combine(threshold_date, parse_time(end_time))

    async def worker():
        while datetime.utcnow() <= end_dt:
            await _record_snapshot(device_id, threshold_id, lat, lon)
            await asyncio.sleep(interval)

    if datetime.utcnow() <= end_dt:
        asyncio.create_task(worker())


async def fetch_weather_history(threshold_id: str) -> List[Dict[str, object]]:
    cursor = weather_history_collection.find({"threshold_id": threshold_id}).sort(
        "timestamp", 1
    )
    results: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        results.append(doc)
    return results
