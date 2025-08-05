import pytest
from fastapi.testclient import TestClient

from main import app
from routes import thresholds as threshold_route

client = TestClient(app)


@pytest.fixture(autouse=True)
def mock_upsert(monkeypatch):
    async def fake_upsert_threshold(threshold):
        return {"status": "ok"}

    monkeypatch.setattr(threshold_route, "upsert_threshold", fake_upsert_threshold)


def test_set_threshold_success():
    payload = {
        "device_id": "device123",
        "date": "2024-01-01",
        "start_time": "08:00",
        "weather_limits": {
            "max_wind_speed": 10,
            "max_rain_intensity": 5,
            "max_humidity": 80,
            "min_temperature": 0,
            "max_temperature": 35,
            "headwind_sensitivity": 20,
            "crosswind_sensitivity": 15,
        },
        "office_location": {"latitude": 0, "longitude": 0},
        "commute_windows": {"morning": "07:30", "evening": "17:30"},
    }
    response = client.post("/thresholds", json=payload)
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_set_threshold_validation_error():
    payload = {
        "device_id": "device123",
        "date": "invalid-date",
        "start_time": "8",
        "weather_limits": {},
        "office_location": {"latitude": 0, "longitude": 0},
    }
    response = client.post("/thresholds", json=payload)
    assert response.status_code == 422
