from services.commute_evaluator import evaluate_thresholds
from models.thresholds import WeatherLimits


def test_evaluate_thresholds_flags():
    weather = {
        "wind_speed": 15,
        "rain": 3,
        "humidity": 90,
        "temp": 35,
        "visibility": 500,
        "uvi": 9,
        "pollution": 120,
    }
    limits = WeatherLimits(
        max_wind_speed=10,
        max_rain_intensity=2,
        max_humidity=80,
        min_temperature=5,
        max_temperature=30,
        min_visibility=1000,
        max_uv_index=8,
        max_pollution=100,
    )
    msgs = evaluate_thresholds(weather, limits)
    assert "Wind speed exceeds your comfort limit" in msgs
    assert "Rain intensity exceeds your comfort limit" in msgs
    assert "Humidity exceeds your comfort limit" in msgs
    assert "Temperature is above your comfort range" in msgs
    assert "Visibility is below your comfort limit" in msgs
    assert "UV index exceeds your comfort limit" in msgs
    assert "Pollution exceeds your comfort limit" in msgs


def test_evaluate_thresholds_no_flags():
    weather = {"wind_speed": 5, "rain": 0, "humidity": 50, "temp": 20, "visibility": 2000, "uvi": 1}
    limits = WeatherLimits(
        max_wind_speed=10,
        max_rain_intensity=2,
        max_humidity=80,
        min_temperature=5,
        max_temperature=30,
        min_visibility=1000,
        max_uv_index=8,
        max_pollution=100,
    )
    msgs = evaluate_thresholds(weather, limits)
    assert msgs == []
