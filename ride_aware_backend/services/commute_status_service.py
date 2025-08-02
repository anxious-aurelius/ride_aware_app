from datetime import datetime
from utils.commute_window import parse_time, is_within_commute_window
from services.weather_service import get_hourly_forecast
from services.threshold_evaluator import evaluate_thresholds
from services.recommendation_engine import generate_recommendations
from models.thresholds import Thresholds


def get_commute_status(
    thresholds: Thresholds,
) -> dict:
    """
    Main function to evaluate today's commute status and suggestions.
    """
    # parse commute window times from model
    if thresholds.commute_windows:
        start_time = parse_time(thresholds.commute_windows.morning)
        end_time = parse_time(thresholds.commute_windows.evening)
    else:
        start_time = parse_time("00:00")
        end_time = parse_time("23:59")

    # determine now and window membership
    now = datetime.now()
    in_window = is_within_commute_window(now, start_time, end_time)

    # compute elapsed minutes since window start
    today = now.date()
    elapsed = (now - datetime.combine(today, start_time)).total_seconds() / 60

    # forecast at expected end of window
    arrival_dt = datetime.combine(today, end_time)
    location_str = f"{thresholds.office_location.latitude},{thresholds.office_location.longitude}"
    weather = get_hourly_forecast(location_str, arrival_dt)

    # build flat threshold dict for evaluator
    flat_thresholds = {
        "max_wind_speed": float(thresholds.weather_limits.max_wind_speed),
        "max_rain_intensity": float(thresholds.weather_limits.max_rain_intensity),
        "max_humidity": float(thresholds.weather_limits.max_humidity),
        "min_temperature": float(thresholds.weather_limits.min_temperature),
        "max_temperature": float(thresholds.weather_limits.max_temperature),
        "headwind_sensitivity": float(
            thresholds.weather_limits.headwind_sensitivity
        ),
        "crosswind_sensitivity": float(
            thresholds.weather_limits.crosswind_sensitivity
        ),
    }

    # evaluate thresholds
    evaluation = evaluate_thresholds(elapsed, weather, flat_thresholds)

    # generate suggestions
    suggestions = generate_recommendations(evaluation)

    return {
        "in_commute_window": in_window,
        "elapsed_minutes": elapsed,
        "evaluation": evaluation,
        "suggestions": suggestions
    }