import os
from datetime import datetime
import pytest


def make_response(data):
    class Response:
        def __init__(self, json_data):
            self._json = json_data
        def json(self):
            return self._json
        def raise_for_status(self):
            pass
    return Response(data)


def test_get_hourly_forecast(monkeypatch):
    monkeypatch.setenv("OWM_API_KEY", "key")
    from utils.weather import get_hourly_forecast
    dt = datetime(2023, 1, 1, 12, 0)
    hourly = [{"dt": int(dt.timestamp()), "temp": 280}]
    monkeypatch.setattr("utils.weather.requests.get", lambda url: make_response({"hourly": hourly}))
    result = get_hourly_forecast("1,2", dt)
    assert result["temp"] == 280


def test_get_hourly_forecast_no_match(monkeypatch):
    monkeypatch.setenv("OWM_API_KEY", "key")
    from utils.weather import get_hourly_forecast
    dt = datetime(2023, 1, 1, 12, 0)
    hourly = [{"dt": int(dt.timestamp()) + 7200, "temp": 280}]
    monkeypatch.setattr("utils.weather.requests.get", lambda url: make_response({"hourly": hourly}))
    with pytest.raises(ValueError):
        get_hourly_forecast("1,2", dt)
