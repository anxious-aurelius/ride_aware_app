# services/weather_history_service.py
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, date, timedelta
from typing import List, Dict, Any, Optional
from zoneinfo import ZoneInfo
from bson import ObjectId

from models.weather_history import RouteWeatherSnapshot
from services.db import weather_history_collection, routes_collection
from services.weather_service import get_hourly_forecast
from utils.commute_window import parse_time

logger = logging.getLogger(__name__)


def _haversine(a: Dict[str, float], b: Dict[str, float]) -> float:
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
    today = date.today()
    start_dt = datetime.combine(today, parse_time(start_time))
    end_dt = datetime.combine(today, parse_time(end_time))
    total = (end_dt - start_dt).total_seconds()
    if distance_km <= 0:
        return int(total)
    return max(1, int(total / distance_km))


def _id_filter(threshold_id: str) -> Dict[str, Any]:
    """
    Match either string-threshold_id or ObjectId(threshold_id) in case existing
    rows were written with different types.
    """
    ors = [{"threshold_id": threshold_id}]
    try:
        ors.append({"threshold_id": ObjectId(threshold_id)})
    except Exception:
        pass
    return {"$or": ors}


async def _record_snapshot(
    device_id: str, threshold_id: str, lat: float, lon: float, now: datetime
) -> None:
    """Fetch and store a single weather snapshot."""
    weather = get_hourly_forecast(lat, lon, now)
    snap = RouteWeatherSnapshot(
        device_id=device_id,
        threshold_id=threshold_id,
        timestamp=now,
        weather=weather,
    )
    await weather_history_collection.insert_one(snap.model_dump(mode="json"))


async def record_weather_ping(
    *,
    device_id: str,
    threshold_id: str,
    lat: float,
    lon: float,
    timestamp: Optional[datetime] = None,
) -> None:
    """Public helper for the /weatherHistory/ping route."""
    now = timestamp or datetime.now(ZoneInfo(datetime.now().astimezone().tzinfo.key))
    await _record_snapshot(device_id, threshold_id, lat, lon, now)


async def schedule_weather_collection(
    device_id: str,
    threshold_id: str,
    date_str: str,
    start_time: str,
    end_time: str,
    *,
    timezone_str: str | None = None,
    interval_minutes: int = 10,
) -> None:
    """Collect weather snapshots only during the ride window."""
    route_doc = await routes_collection.find_one({"device_id": device_id})
    if not route_doc:
        logger.info("No route for %s; skipping weather collection", device_id)
        return

    points: List[Dict[str, float]] = route_doc.get("route_points") or []
    if not points:
        logger.info("Route %s has no points; skipping", device_id)
        return

    lat = float(points[0]["latitude"])
    lon = float(points[0]["longitude"])

    tz = ZoneInfo(timezone_str) if timezone_str else ZoneInfo(datetime.now().astimezone().tzinfo.key)
    ride_date = date.fromisoformat(date_str)
    start_dt = datetime.combine(ride_date, parse_time(start_time), tzinfo=tz)
    end_dt = datetime.combine(ride_date, parse_time(end_time), tzinfo=tz)

    interval = timedelta(minutes=interval_minutes)

    async def worker():
        now = datetime.now(tz)
        if now >= end_dt:
            return
        if now < start_dt:
            await asyncio.sleep((start_dt - now).total_seconds())
        curr = max(datetime.now(tz), start_dt)
        while curr < end_dt:
            await _record_snapshot(device_id, threshold_id, lat, lon, curr)
            next_tick = curr + interval
            if next_tick >= end_dt:
                break
            await asyncio.sleep((next_tick - curr).total_seconds())
            curr = datetime.now(tz)

    asyncio.create_task(worker())


async def fetch_weather_history(threshold_id: str) -> List[Dict[str, object]]:
    cursor = weather_history_collection.find(_id_filter(threshold_id)).sort("timestamp", 1)
    results: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        results.append(doc)
    return results


async def fetch_weather_history_window(
    *,
    threshold_id: str,
    date_str: str,
    start_time: str,
    end_time: str,
    timezone_str: str | None,
) -> List[Dict[str, object]]:
    tz = ZoneInfo(timezone_str) if timezone_str else ZoneInfo(datetime.now().astimezone().tzinfo.key)
    ride_date = date.fromisoformat(date_str)
    start_dt = datetime.combine(ride_date, parse_time(start_time), tzinfo=tz)
    end_dt = datetime.combine(ride_date, parse_time(end_time), tzinfo=tz)

    q = {
        **_id_filter(threshold_id),
        "timestamp": {"$gte": start_dt, "$lte": end_dt},
    }
    cursor = weather_history_collection.find(q).sort("timestamp", 1)
    out: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        out.append(doc)
    return out
