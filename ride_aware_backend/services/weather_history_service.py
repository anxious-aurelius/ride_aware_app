from __future__ import annotations

import asyncio
import logging
from datetime import datetime, date, timedelta
from typing import List, Dict, Tuple
from zoneinfo import ZoneInfo

from models.weather_history import RouteWeatherSnapshot
from services.db import weather_history_collection, routes_collection
from services.weather_service import get_hourly_forecast
from utils.commute_window import parse_time

logger = logging.getLogger(__name__)

# keep refs so tasks aren't GC'd
_SCHEDULED: set[asyncio.Task] = set()


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


def _cumulative_distances(points: List[Dict[str, float]]) -> Tuple[List[float], float]:
    if len(points) < 2:
        return [0.0], 0.0
    cum = [0.0]
    for i in range(len(points) - 1):
        d = _haversine(points[i], points[i + 1])
        cum.append(cum[-1] + d)
    return cum, cum[-1]


def _interp_point(points: List[Dict[str, float]], cum: List[float], target_km: float) -> Tuple[float, float]:
    if not points:
        raise ValueError("No route points")
    if len(points) == 1:
        return float(points[0]["latitude"]), float(points[0]["longitude"])

    if target_km <= 0:
        p = points[0]
        return float(p["latitude"]), float(p["longitude"])
    if target_km >= cum[-1]:
        p = points[-1]
        return float(p["latitude"]), float(p["longitude"])

    import bisect
    idx = bisect.bisect_right(cum, target_km) - 1
    idx = max(0, min(idx, len(points) - 2))
    seg_len = cum[idx + 1] - cum[idx]
    if seg_len <= 0:
        p = points[idx]
        return float(p["latitude"]), float(p["longitude"])
    t = (target_km - cum[idx]) / seg_len

    a = points[idx]
    b = points[idx + 1]
    lat = float(a["latitude"]) + t * (float(b["latitude"]) - float(a["latitude"]))
    lon = float(a["longitude"]) + t * (float(b["longitude"]) - float(a["longitude"]))
    return lat, lon


async def _record_snapshot(device_id: str, threshold_id: str, lat: float, lon: float, when: datetime) -> None:
    try:
        weather = get_hourly_forecast(lat, lon, when)
    except Exception as e:
        logger.warning("Weather fetch failed for %s @ %s: %s", threshold_id, when, e)
        return

    snap = RouteWeatherSnapshot(
        device_id=device_id,
        threshold_id=threshold_id,
        timestamp=when,
        weather=weather,
    )
    await weather_history_collection.insert_one(snap.model_dump(mode="json"))


async def _collect_over_window(
    *,
    device_id: str,
    threshold_id: str,
    points: List[Dict[str, float]],
    tz: ZoneInfo,
    start_dt: datetime,
    end_dt: datetime,
    interval: timedelta,
    live: bool,
) -> None:
    if not points:
        logger.info("No route points for %s; skipping weather collection", device_id)
        return

    cum, total_km = _cumulative_distances(points)
    total_sec = max(1.0, (end_dt - start_dt).total_seconds())

    async def do_tick(now_dt: datetime):
        elapsed = min(max((now_dt - start_dt).total_seconds(), 0.0), total_sec)
        frac = elapsed / total_sec
        target_km = total_km * frac
        lat, lon = _interp_point(points, cum, target_km)
        await _record_snapshot(device_id, threshold_id, lat, lon, now_dt)

    if live:
        curr = datetime.now(tz)
        if curr < start_dt:
            await asyncio.sleep((start_dt - curr).total_seconds())
            curr = datetime.now(tz)

        while curr < end_dt:
            await do_tick(curr)
            nxt = curr + interval
            if nxt >= end_dt:
                break
            await asyncio.sleep((nxt - curr).total_seconds())
            curr = datetime.now(tz)
        await do_tick(min(datetime.now(tz), end_dt))
    else:
        curr = start_dt
        while curr <= end_dt:
            await do_tick(curr)
            curr += interval


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
    Collect snapshots during the ride window.
    - Live if called before/during the window.
    - Backfill immediately if called after the window.
    """
    route_doc = await routes_collection.find_one({"device_id": device_id})
    points: List[Dict[str, float]] = (route_doc or {}).get("route_points") or []
    if not points:
        logger.info("Route not found/empty for %s; skipping weather collection", device_id)
        return

    tz = ZoneInfo(timezone_str) if timezone_str else ZoneInfo(datetime.now().astimezone().tzinfo.key)
    ride_date = date.fromisoformat(date_str)
    start_dt = datetime.combine(ride_date, parse_time(start_time), tzinfo=tz)
    end_dt = datetime.combine(ride_date, parse_time(end_time), tzinfo=tz)
    if end_dt <= start_dt:
        end_dt = start_dt + timedelta(minutes=max(1, int(interval_minutes)))

    interval = timedelta(minutes=max(1, int(interval_minutes)))
    now = datetime.now(tz)
    live = now < end_dt

    async def runner():
        try:
            await _collect_over_window(
                device_id=device_id,
                threshold_id=threshold_id,
                points=points,
                tz=tz,
                start_dt=start_dt,
                end_dt=end_dt,
                interval=interval,
                live=live,
            )
        except Exception as e:
            logger.exception("Weather collection task failed for %s: %s", threshold_id, e)

    task = asyncio.create_task(runner(), name=f"weather-{threshold_id}")
    _SCHEDULED.add(task)
    task.add_done_callback(_SCHEDULED.discard)


# ---- READ APIs --------------------------------------------------------------

async def fetch_weather_history(threshold_id: str) -> List[Dict[str, object]]:
    """All snapshots for a threshold, sorted by time."""
    cursor = weather_history_collection.find({"threshold_id": threshold_id}).sort("timestamp", 1)
    results: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        results.append(doc)
    return results


async def fetch_weather_history_window(
    threshold_id: str,
    start_dt: datetime,
    end_dt: datetime,
) -> List[Dict[str, object]]:
    """Snapshots for a threshold constrained to [start_dt, end_dt]."""
    cursor = weather_history_collection.find(
        {
            "threshold_id": threshold_id,
            "timestamp": {"$gte": start_dt, "$lte": end_dt},
        }
    ).sort("timestamp", 1)
    results: List[Dict[str, object]] = []
    async for doc in cursor:
        doc.pop("_id", None)
        results.append(doc)
    return results
