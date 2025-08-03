from fastapi.testclient import TestClient
from fastapi import FastAPI

from routes import commute_status
from services.weather_service import MissingAPIKeyError


def test_commute_status_missing_api_key(monkeypatch):
    async def fake_get_status(device_id: str):
        raise MissingAPIKeyError("OPENWEATHER_API_KEY environment variable not set")

    monkeypatch.setattr(commute_status, "get_status", fake_get_status)

    app = FastAPI()
    app.include_router(commute_status.router)
    client = TestClient(app)

    resp = client.get("/commute/status/abc")
    assert resp.status_code == 500
    assert resp.json()["detail"] == "OPENWEATHER_API_KEY environment variable not set"

