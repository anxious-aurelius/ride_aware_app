import asyncio
import pytest
from unittest.mock import AsyncMock

from controllers import threshold_controller
from models.thresholds import Thresholds, WeatherLimits, OfficeLocation


def test_upsert_threshold(monkeypatch):
    thresholds = Thresholds(
        device_id="device123",
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
    result_obj = type("R", (), {"modified_count": 1, "upserted_id": "id"})()
    collection = type("C", (), {"update_one": AsyncMock(return_value=result_obj)})()
    monkeypatch.setattr(threshold_controller, "thresholds_collection", collection)
    result = asyncio.run(threshold_controller.upsert_threshold(thresholds))
    collection.update_one.assert_called_once()
    assert result["status"] == "ok"


def test_get_thresholds(monkeypatch):
    doc = {
        "device_id": "device123",
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
    result = asyncio.run(threshold_controller.get_thresholds("device123"))
    assert result["device_id"] == "device123"


def test_get_thresholds_not_found(monkeypatch):
    collection = type("C", (), {"find_one": AsyncMock(return_value=None)})()
    monkeypatch.setattr(threshold_controller, "thresholds_collection", collection)
    with pytest.raises(threshold_controller.HTTPException):
        asyncio.run(threshold_controller.get_thresholds("device123"))
