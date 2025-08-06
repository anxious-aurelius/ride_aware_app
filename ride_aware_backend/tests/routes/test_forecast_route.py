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


def test_route_forecast(monkeypatch):
    async def fake_eval_route(points, time, thresholds):
        return {
            "status": "ok",
            "issues": [],
            "borderline": [],
            "summary": {"max_wind_speed": 5},
            "points": [],
        }

    monkeypatch.setattr(forecast, "evaluate_route", fake_eval_route)

    app = FastAPI()
    app.include_router(forecast.router)
    client = TestClient(app)

    body = {
        "points": [{"latitude": 1.0, "longitude": 2.0}],
        "time": "2024-01-01T08:00:00",
        "thresholds": {
            "max_wind_speed": 10,
            "max_rain_intensity": 5,
            "max_humidity": 80,
            "min_temperature": 0,
            "max_temperature": 30,
            "headwind_sensitivity": 20,
            "crosswind_sensitivity": 15,
        },
    }

    resp = client.post("/api/forecast/route", json=body)
    assert resp.status_code == 200
    assert resp.json()["summary"]["max_wind_speed"] == 5


def test_forecast_next(monkeypatch):
    async def fake_next_hours(lat: float, lon: float, hours: int):
        return [{"temp": 20}]

    monkeypatch.setattr(forecast, "get_next_hours", fake_next_hours)

    app = FastAPI()
    app.include_router(forecast.router)
    client = TestClient(app)

    resp = client.get(
        "/api/forecast/next",
        params={"lat": 1.0, "lon": 2.0, "hours": 6},
    )
    assert resp.status_code == 200
    assert resp.json()[0]["temp"] == 20
