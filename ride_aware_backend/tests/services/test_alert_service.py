import asyncio
from datetime import date, timedelta
from unittest.mock import AsyncMock

from services import alert_service


def _threshold_doc(d: str) -> dict:
    return {
        "device_id": "device1",
        "date": d,
        "start_time": "08:00",
        "end_time": "09:00",
        "presence_radius_m": 100,
        "speed_cutoff_kmh": 5,
        "weather_limits": {
            "max_wind_speed": 10,
            "max_rain_intensity": 5,
            "max_humidity": 80,
            "min_temperature": 0,
            "max_temperature": 30,
            "headwind_sensitivity": 20,
            "crosswind_sensitivity": 15,
        },
        "office_location": {"latitude": 0, "longitude": 0},
    }


def test_schedule_existing_alerts(monkeypatch):
    today = date.today()
    docs = [
        _threshold_doc(today.isoformat()),
        _threshold_doc((today + timedelta(days=1)).isoformat()),
    ]

    async def cursor_gen():
        for d in docs:
            yield d

    class Collection:
        def find(self, query):
            return cursor_gen()

    monkeypatch.setattr(alert_service, "thresholds_collection", Collection())

    pre = AsyncMock()
    rem = AsyncMock()
    monkeypatch.setattr(alert_service, "schedule_pre_route_alert", pre)
    monkeypatch.setattr(alert_service, "schedule_feedback_reminder", rem)

    asyncio.run(alert_service.schedule_existing_alerts())

    assert pre.await_count == len(docs)
    assert rem.await_count == len(docs)
