from datetime import datetime
import pytest

from services import weather_service


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
    dt = datetime(2023, 1, 1, 12, 0)
    forecast_list = [{"dt": int(dt.timestamp()), "wind": {"speed": 5}}]
    monkeypatch.setenv("OPENWEATHER_API_KEY", "key")
    monkeypatch.delenv("OPENWEATHER_URL", raising=False)
    captured = {}

    def fake_get(url, params=None):
        captured["url"] = url
        captured["params"] = params
        return make_response({"list": forecast_list})

    monkeypatch.setattr(weather_service.requests, "get", fake_get)
    res = weather_service.get_hourly_forecast(1.0, 2.0, dt)
    assert res["wind_speed"] == 5
    assert captured["url"] == "https://api.openweathermap.org/data/2.5/forecast"
    assert captured["params"] == {
        "lat": 1.0,
        "lon": 2.0,
        "appid": "key",
        "units": "metric",
        "cnt": 8,
    }


def test_get_hourly_forecast_no_data(monkeypatch):
    dt = datetime(2023, 1, 1, 12, 0)
    monkeypatch.setenv("OPENWEATHER_API_KEY", "key")
    monkeypatch.delenv("OPENWEATHER_URL", raising=False)
    monkeypatch.setattr(
        weather_service.requests,
        "get",
        lambda url, params=None: make_response({"list": []}),
    )
    with pytest.raises(ValueError):
        weather_service.get_hourly_forecast(1.0, 2.0, dt)


def test_get_hourly_forecast_missing_api_key(monkeypatch):
    dt = datetime(2023, 1, 1, 12, 0)
    monkeypatch.delenv("OPENWEATHER_API_KEY", raising=False)
    with pytest.raises(weather_service.MissingAPIKeyError):
        weather_service.get_hourly_forecast(1.0, 2.0, dt)
