from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, date

from models.thresholds import Thresholds
from services.db import fcm_tokens_collection
from services.weather_service import get_next_hours_forecast
from services.commute_evaluator import evaluate_thresholds
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
    device_id = threshold.device_id
    lat = float(threshold.office_location.latitude)
    lon = float(threshold.office_location.longitude)
    forecasts = get_next_hours_forecast(lat, lon, 6)
    for snap in forecasts:
        if evaluate_thresholds(snap, threshold.weather_limits):
            await _send_notification(device_id, "Weather conditions may be harsh. Be prepared!")
            break


async def schedule_pre_route_alert(threshold: Thresholds) -> None:
    """Schedule an alert 3 hours before commute start."""
    today = date.fromisoformat(threshold.date)
    start_dt = datetime.combine(today, parse_time(threshold.start_time))
    alert_dt = start_dt - timedelta(hours=3)

    async def worker():
        delay = (alert_dt - datetime.utcnow()).total_seconds()
        if delay > 0:
            await asyncio.sleep(delay)
        await _check_and_notify(threshold)

    asyncio.create_task(worker())
