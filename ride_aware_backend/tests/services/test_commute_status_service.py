from datetime import datetime

from models.thresholds import Thresholds, WeatherLimits, EnvironmentalRisk, OfficeLocation


def test_get_commute_status(monkeypatch):
    from services import commute_status_service as css

    class FixedDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2023, 1, 1, 8, 30)

    monkeypatch.setattr(css, "datetime", FixedDateTime)
    monkeypatch.setattr(css, "get_hourly_forecast", lambda *a, **k: {"wind_speed": 5})
    monkeypatch.setattr(css, "evaluate_thresholds", lambda *a, **k: {"time_exceeded": False, "weather_warning": False})
    monkeypatch.setattr(css, "generate_recommendations", lambda *a, **k: ["All good"])

    thresholds = Thresholds(
        device_id="device123",
        weather_limits=WeatherLimits(
            max_wind_speed=10,
            max_rain_intensity=5,
            max_humidity=80,
            min_temperature=0,
            max_temperature=35,
        ),
        environmental_risk=EnvironmentalRisk(
            min_visibility=1000,
            max_pollution=100,
            max_uv_index=8,
        ),
        office_location=OfficeLocation(latitude=0, longitude=0),
    )

    result = css.get_commute_status(thresholds)
    assert result["in_commute_window"] is True
    assert result["suggestions"] == ["All good"]
