from datetime import datetime
import pytest


def make_response(data):
    class Resp:
        def __init__(self, d):
            self._d = d
        def json(self):
            return self._d
        def raise_for_status(self):
            pass
    return Resp(data)


def test_get_hourly_forecast(monkeypatch):
    from services import weather_service
    dt = datetime(2023, 1, 1, 12, 0)
    hourly = [{"dt": int(dt.timestamp()), "temp": 270}]
    monkeypatch.setattr(weather_service.requests, "get", lambda url: make_response({"hourly": hourly}))
    res = weather_service.get_hourly_forecast("1,2", dt, "key")
    assert res["temp"] == 270


def test_get_hourly_forecast_no_match(monkeypatch):
    from services import weather_service
    dt = datetime(2023, 1, 1, 12, 0)
    hourly = [{"dt": int(dt.timestamp()) + 7200, "temp": 270}]
    monkeypatch.setattr(weather_service.requests, "get", lambda url: make_response({"hourly": hourly}))
    with pytest.raises(ValueError):
        weather_service.get_hourly_forecast("1,2", dt, "key")
