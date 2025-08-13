from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, date
from zoneinfo import ZoneInfo

from models.thresholds import Thresholds
from services.db import fcm_tokens_collection, thresholds_collection
from services.weather_service import get_next_hours_forecast
from services.threshold_eval import evaluate_forecast_point, summarize_breaches
from utils.commute_window import parse_time

logger = logging.getLogger(__name__)


async def _send_notification(device_id: str, message: str) -> None:
    """Send notification to device if token is available."""
    doc = await fcm_tokens_collection.find_one({"device_id": device_id})
    token = doc.get("fcm_token") if doc else None
    if token:
        logger.info("Would send notification to %s: %s", device_id, message)
    else:
        logger.warning("No FCM token for %s; skipping notification", device_id)


async def _check_and_notify(threshold: Thresholds) -> None:
    """Fetch upcoming forecast and notify with actionable advice."""

    device_id = threshold.device_id
    lat = float(threshold.office_location.latitude)
    lon = float(threshold.office_location.longitude)
    forecasts = get_next_hours_forecast(lat, lon, 6)
    limits = threshold.weather_limits.model_dump() if hasattr(threshold, "weather_limits") else {}
    breaches_per_hour = [evaluate_forecast_point(f, limits) for f in forecasts]
    message = summarize_breaches(breaches_per_hour)
    if message:
        await _send_notification(device_id, message)
    else:
        await _send_notification(device_id, "Conditions look fine for your ride.")


async def schedule_pre_route_alert(threshold: Thresholds) -> None:
    """Schedule an alert three hours before commute start respecting timezone."""

    tz_name = getattr(threshold, "timezone", None) or datetime.now().astimezone().tzinfo.key
    tz = ZoneInfo(tz_name)
    ride_date = date.fromisoformat(threshold.date)
    start_dt = datetime.combine(ride_date, parse_time(threshold.start_time), tzinfo=tz)
    alert_dt = start_dt - timedelta(hours=3)

    async def worker():
        now = datetime.now(tz)
        delay = (alert_dt - now).total_seconds()
        if delay > 0:
            await asyncio.sleep(delay)
        await _check_and_notify(threshold)

    asyncio.create_task(worker())


async def schedule_feedback_reminder(threshold: Thresholds) -> None:
    """Schedule a feedback reminder one hour after commute end."""

    tz_name = getattr(threshold, "timezone", None) or datetime.now().astimezone().tzinfo.key
    tz = ZoneInfo(tz_name)
    ride_date = date.fromisoformat(threshold.date)
    end_dt = datetime.combine(
        ride_date, parse_time(threshold.end_time), tzinfo=tz
    )
    reminder_dt = end_dt + timedelta(hours=1)

    async def worker():
        now = datetime.now(tz)
        delay = (reminder_dt - now).total_seconds()
        if delay > 0:
            await asyncio.sleep(delay)
        await _send_notification(
            threshold.device_id,
            "How was your ride? Please share quick feedback to improve your route tips.",
        )

    asyncio.create_task(worker())


async def schedule_existing_alerts() -> None:
    """Reschedule alerts for all upcoming rides stored in the database."""

    today = date.today().isoformat()
    cursor = thresholds_collection.find({"date": {"$gte": today}})
    async for doc in cursor:
        doc.pop("_id", None)
        threshold = Thresholds(**doc)
        await schedule_pre_route_alert(threshold)
        await schedule_feedback_reminder(threshold)
