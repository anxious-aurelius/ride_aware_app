from services.threshold_evaluator import evaluate_thresholds


def test_evaluate_thresholds_flags():
    thresholds = {
        "max_commute_minutes": 30,
        "max_wind_speed": 5,
        "headwind_sensitivity": 10,
        "crosswind_sensitivity": 7,
    }
    weather = {"wind_speed": 6, "headwind_speed": 11, "crosswind_speed": 8}
    result = evaluate_thresholds(40, weather, thresholds)
    assert result["time_exceeded"]
    assert result["weather_warning"]
    assert "wind_speed" in result["details"]


def test_evaluate_thresholds_no_flags():
    result = evaluate_thresholds(10, {}, {})
    assert not result["time_exceeded"]
    assert not result["weather_warning"]
