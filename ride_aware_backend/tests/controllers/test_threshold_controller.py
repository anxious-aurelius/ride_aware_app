import asyncio
import pytest
from unittest.mock import AsyncMock

from controllers import threshold_controller
from models.thresholds import Thresholds, WeatherLimits, OfficeLocation


def _sample_thresholds() -> Thresholds:
    return Thresholds(
        device_id="device123",
        date="2024-01-01",
        start_time="08:00",
        end_time="17:00",
        weather_limits=WeatherLimits(
            max_wind_speed=10,
            max_rain_intensity=5,
            max_humidity=80,
            min_temperature=0,
            max_temperature=35,
            min_visibility=1000,
            max_pollution=100,
            max_uv_index=8,
        ),
        office_location=OfficeLocation(latitude=0, longitude=0),
    )


def test_upsert_threshold_insert(monkeypatch):
    thresholds = _sample_thresholds()
    collection = type(
        "C",
        (),
        {
            "find_one": AsyncMock(return_value=None),
            "insert_one": AsyncMock(
                return_value=type("R", (), {"inserted_id": "id", "modified_count": 0})()
            ),
        },
    )()
    monkeypatch.setattr(threshold_controller, "thresholds_collection", collection)
    create_fb = AsyncMock()
    monkeypatch.setattr(threshold_controller, "create_feedback_entry", create_fb)

    result = asyncio.run(threshold_controller.upsert_threshold(thresholds))

    collection.find_one.assert_awaited_once()
    collection.insert_one.assert_awaited_once()
    create_fb.assert_awaited_once_with("device123", "id")
    assert result["threshold_id"] == "id"
    assert result["status"] == "ok"


def test_upsert_threshold_update(monkeypatch):
    thresholds = _sample_thresholds()
    collection = type(
        "C",
        (),
        {
            "find_one": AsyncMock(return_value={"_id": "existing"}),
            "update_one": AsyncMock(
                return_value=type("R", (), {"modified_count": 1, "upserted_id": None})()
            ),
        },
    )()
    monkeypatch.setattr(threshold_controller, "thresholds_collection", collection)
    create_fb = AsyncMock()
    monkeypatch.setattr(threshold_controller, "create_feedback_entry", create_fb)

    result = asyncio.run(threshold_controller.upsert_threshold(thresholds))

    collection.find_one.assert_awaited_once()
    collection.update_one.assert_awaited_once()
    create_fb.assert_awaited_once_with("device123", "existing")
    assert result["threshold_id"] == "existing"
    assert result["status"] == "ok"


def test_get_thresholds(monkeypatch):
    doc = {
        "device_id": "device123",
        "date": "2024-01-01",
        "start_time": "08:00",
        "end_time": "17:00",
        "weather_limits": {
            "max_wind_speed": 10,
            "max_rain_intensity": 5,
            "max_humidity": 80,
            "min_temperature": 0,
            "max_temperature": 35,
            "headwind_sensitivity": 20,
            "crosswind_sensitivity": 15,
            "min_visibility": 1000,
            "max_pollution": 100,
            "max_uv_index": 8,
        },
        "office_location": {"latitude": 0, "longitude": 0},
    }
    collection = type("C", (), {"find_one": AsyncMock(return_value=dict(doc))})()
    monkeypatch.setattr(threshold_controller, "thresholds_collection", collection)
    result = asyncio.run(
        threshold_controller.get_thresholds("device123", "2024-01-01", "08:00", "17:00")
    )
    assert result["device_id"] == "device123"


def test_get_thresholds_not_found(monkeypatch):
    collection = type("C", (), {"find_one": AsyncMock(return_value=None)})()
    monkeypatch.setattr(threshold_controller, "thresholds_collection", collection)
    with pytest.raises(threshold_controller.HTTPException):
        asyncio.run(
            threshold_controller.get_thresholds(
                "device123", "2024-01-01", "08:00", "17:00"
            )
        )
