# services/weather_history_service.py
from __future__ import annotations
import asyncio
import logging
from datetime import datetime, date, timedelta
from typing import List, Dict, Optional
from zoneinfo import ZoneInfo

from models.weather_history import RouteWeatherSnapshot
from services.db import weather_history_collection, routes_collection
from services.weather_service import get_hourly_forecast
from utils.commute_window import parse_time

logger = logging.getLogger(__name__)

# ---- core helpers -----------------------------------------------------------

async def record_snapshot(
    *,
    device_id: str,
    threshold_id: str,
    lat: float,
    lon: float,
    when: datetime,
) -> None:
    """Fetch and store a single weather snapshot for a given time & location."""
    weather = get_hourly_forecast(lat, lon, when)
    snap = RouteWeatherSnapshot(
        device_id=device_id,
        threshold_id=threshold_id,
        timestamp=when,
        weather=weather,
    )
    await weather_history_collection.insert_one(snap.model_dump(mode="json"))


async def fetch_weather_history(threshold_id: str) -> List[Dict[str, object]]:
    cursor = weather_history_collection.find(
        {"threshold_id": threshold_id}
    ).sort("timestamp", 1)
    out: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        out.append(doc)
    return out


async def fetch_weather_history_window(
    *,
    threshold_id: str,
    start_dt: datetime,
    end_dt: datetime,
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

# ---- backfill & scheduling --------------------------------------------------

async def _get_track_latlon(device_id: str, fallback: Optional[Dict] = None) -> Optional[tuple[float, float]]:
    """Pick a reasonable lat/lon to sample if the app isn't pinging live.
    Uses the first saved route point; falls back to office_location if provided.
    """
    route_doc = await routes_collection.find_one({"device_id": device_id})
    if route_doc:
        pts = (route_doc.get("route_points") or [])
        if pts:
            try:
                return float(pts[0]["latitude"]), float(pts[0]["longitude"])
            except Exception:
                pass
    if fallback:
        try:
            return float(fallback["latitude"]), float(fallback["longitude"])
        except Exception:
            pass
    return None


async def backfill_weather_history(
    *,
    device_id: str,
    threshold_id: str,
    date_str: str,
    start_time: str,
    end_time: str,
    timezone_str: Optional[str],
    interval_minutes: int = 10,
    office_location: Optional[Dict] = None,
    limit_points: int = 48,  # safety cap (8 hours @ 10 min)
) -> None:
    """Create snapshots for the portion of the window that has already elapsed."""
    tz = ZoneInfo(timezone_str) if timezone_str else ZoneInfo(datetime.now().astimezone().tzinfo.key)
    ride_date = date.fromisoformat(date_str)
    start_dt = datetime.combine(ride_date, parse_time(start_time), tzinfo=tz)
    end_dt = datetime.combine(ride_date, parse_time(end_time), tzinfo=tz)
    now = datetime.now(tz)

    # Nothing to backfill yet.
    if now <= start_dt:
        return

    upto = min(now, end_dt)
    if upto <= start_dt:
        return

    if await weather_history_collection.count_documents({"threshold_id": threshold_id}) > 0:
        return  # already have something, don't double-write

    track = await _get_track_latlon(device_id, office_location)
    if not track:
        logger.info("No route/office location for %s; skipping backfill", device_id)
        return

    lat, lon = track
    interval = timedelta(minutes=interval_minutes)

    curr = start_dt
    points = 0
    while curr <= upto and points < limit_points:
        try:
            await record_snapshot(
                device_id=device_id,
                threshold_id=threshold_id,
                lat=lat,
                lon=lon,
                when=curr,
            )
        except Exception as e:
            logger.warning("Backfill snapshot failed (%s @ %s): %s", threshold_id, curr, e)
        points += 1
        curr += interval


async def schedule_weather_collection(
    *,
    device_id: str,
    threshold_id: str,
    date_str: str,
    start_time: str,
    end_time: str,
    timezone_str: Optional[str] = None,
    interval_minutes: int = 10,
    office_location: Optional[Dict] = None,
) -> None:
    """Collect snapshots during the remaining window time.
    If the app reloads, this task will be lost; the backfill ensures you still get data.
    """
    track = await _get_track_latlon(device_id, office_location)
    if not track:
        logger.info("No route/office location for %s; skipping scheduled collection", device_id)
        return
    lat, lon = track

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
            try:
                await record_snapshot(
                    device_id=device_id,
                    threshold_id=threshold_id,
                    lat=lat,
                    lon=lon,
                    when=curr,
                )
            except Exception as e:
                logger.warning("Scheduled snapshot failed (%s @ %s): %s", threshold_id, curr, e)

            next_tick = curr + interval
            if next_tick >= end_dt:
                break
            await asyncio.sleep((next_tick - curr).total_seconds())
            curr = next_tick

    asyncio.create_task(worker())

# ---- optional: live ping from mobile ---------------------------------------

async def record_snapshot_from_device(
    *,
    device_id: str,
    threshold_id: str,
    lat: float,
    lon: float,
    when: Optional[datetime] = None,
) -> None:
    """Store a snapshot using the caller's live location (mobile ping)."""
    when = when or datetime.now().astimezone()
    await record_snapshot(
        device_id=device_id,
        threshold_id=threshold_id,
        lat=lat,
        lon=lon,
        when=when,
    )
