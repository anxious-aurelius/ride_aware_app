# services/weather_history_service.py
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, date, timedelta
from typing import List, Dict
from zoneinfo import ZoneInfo

from models.weather_history import RouteWeatherSnapshot
from services.db import weather_history_collection, routes_collection
from services.weather_service import get_hourly_forecast
from utils.commute_window import parse_time

logger = logging.getLogger(__name__)


async def _record_snapshot(
    device_id: str, threshold_id: str, lat: float, lon: float, when: datetime
) -> None:
    """Fetch and store a single weather snapshot."""
    weather = get_hourly_forecast(lat, lon, when)
    snap = RouteWeatherSnapshot(
        device_id=device_id,
        threshold_id=threshold_id,
        timestamp=when,
        weather=weather,
    )
    await weather_history_collection.insert_one(snap.model_dump(mode="json"))


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
    """
    Collect weather snapshots during the ride window.
    If window is already past, do a backfill across the window.
    """

    route_doc = await routes_collection.find_one({"device_id": device_id})
    if not route_doc:
        logger.info("No route for %s; skipping weather collection", device_id)
        return

    points: List[Dict[str, float]] = route_doc.get("route_points") or []
    if not points:
        logger.info("Route for %s has no points; skipping", device_id)
        return

    # Use first route point for now (simple, consistent)
    lat = float(points[0]["latitude"])
    lon = float(points[0]["longitude"])

    tz = ZoneInfo(timezone_str) if timezone_str else datetime.now().astimezone().tzinfo
    ride_date = date.fromisoformat(date_str)
    start_dt = datetime.combine(ride_date, parse_time(start_time), tzinfo=tz)
    end_dt = datetime.combine(ride_date, parse_time(end_time), tzinfo=tz)
    interval = timedelta(minutes=interval_minutes)

    async def _live():
        now = datetime.now(tz)
        if now >= end_dt:
            return
        if now < start_dt:
            await asyncio.sleep((start_dt - now).total_seconds())
        current = max(datetime.now(tz), start_dt)
        while current < end_dt:
            await _record_snapshot(device_id, threshold_id, lat, lon, current)
            nxt = current + interval
            if nxt >= end_dt:
                break
            await asyncio.sleep((nxt - current).total_seconds())
            current = datetime.now(tz)

    async def _backfill():
        # In case app/server restarted or we created record after the window.
        current = start_dt
        while current < end_dt:
            await _record_snapshot(device_id, threshold_id, lat, lon, current)
            current += interval

    # Decide live vs backfill
    now = datetime.now(tz)
    if now <= end_dt:
        asyncio.create_task(_live())
    else:
        asyncio.create_task(_backfill())


async def fetch_weather_history(threshold_id: str) -> List[Dict[str, object]]:
    cursor = weather_history_collection.find({"threshold_id": threshold_id}).sort(
        "timestamp", 1
    )
    out: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        out.append(doc)
    return out


async def fetch_weather_history_window(
    threshold_id: str, start_dt: datetime, end_dt: datetime
) -> List[Dict[str, object]]:
    cursor = weather_history_collection.find(
        {
            "threshold_id": threshold_id,
            "timestamp": {"$gte": start_dt, "$lte": end_dt},
        }
    ).sort("timestamp", 1)
    out: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        out.append(doc)
    return out
