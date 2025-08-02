from datetime import datetime
from typing import Dict
import requests


def get_hourly_forecast(location: str, dt: datetime, api_key: str) -> Dict:
    """
    Retrieve hourly forecast for a given datetime and location using OpenWeatherMap.
    :param location: "lat,lon"
    :param dt: datetime for which to retrieve forecast
    :param api_key: OWM API key
    """
    lat, lon = location.split(",")
    url = (
        f"https://api.openweathermap.org/data/2.5/onecall?exclude=current,minutely,daily,alerts&"
        f"lat={lat}&lon={lon}&appid={api_key}"
    )
    resp = requests.get(url)
    resp.raise_for_status()
    hourly = resp.json().get("hourly", [])
    # match by hour precision
    target_ts = int(dt.timestamp())
    for hour in hourly:
        if abs(hour.get("dt") - target_ts) < 3600:
            return hour
    raise ValueError(f"No forecast available for {dt}")