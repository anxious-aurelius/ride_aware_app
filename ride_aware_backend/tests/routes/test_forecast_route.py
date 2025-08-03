from fastapi.testclient import TestClient
from fastapi import FastAPI
from fastapi.testclient import TestClient

from routes import forecast
from services.weather_service import MissingAPIKeyError


def test_forecast_success(monkeypatch):
    async def fake_get_forecast(lat: float, lon: float, time):
        return {"temp": 20}

    monkeypatch.setattr(forecast, "get_forecast", fake_get_forecast)

    app = FastAPI()
    app.include_router(forecast.router)
    client = TestClient(app)

    resp = client.get(
        "/api/forecast",
        params={"lat": 1.0, "lon": 2.0, "time": "2024-01-01T08:00:00"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"temp": 20}


def test_forecast_missing_api_key(monkeypatch):
    async def fake_get_forecast(lat: float, lon: float, time):
        raise MissingAPIKeyError("OPENWEATHER_API_KEY environment variable not set")

    monkeypatch.setattr(forecast, "get_forecast", fake_get_forecast)

    app = FastAPI()
    app.include_router(forecast.router)
    client = TestClient(app)

    resp = client.get(
        "/api/forecast",
        params={"lat": 1.0, "lon": 2.0, "time": "2024-01-01T08:00:00"},
    )
    assert resp.status_code == 500
    assert resp.json()["detail"] == "OPENWEATHER_API_KEY environment variable not set"
