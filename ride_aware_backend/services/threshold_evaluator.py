from typing import Dict, Any

def evaluate_thresholds(
    commute_time: float,
    weather_data: Dict[str, Any],
    thresholds: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Compare commute time and weather data against thresholds.
    Returns a dict detailing exceeded thresholds.
    """
    results = {"time_exceeded": False, "weather_warning": False, "details": {}}

    max_commute = thresholds.get("max_commute_minutes")
    if max_commute is not None and commute_time > max_commute:
        results["time_exceeded"] = True
        results["details"]["commute_time"] = {
            "measured": commute_time,
            "threshold": max_commute
        }

    wind_limit = thresholds.get("max_wind_speed")
    wind_speed = weather_data.get("wind_speed")
    if wind_limit is not None and wind_speed and wind_speed > wind_limit:
        results["weather_warning"] = True
        results["details"]["wind_speed"] = {
            "measured": wind_speed,
            "threshold": wind_limit
        }

    return results