import os
from datetime import datetime
from typing import Dict
import requests

# Load API key once, not passed around
API_KEY = os.getenv("OWM_API_KEY")

if not API_KEY:
    raise RuntimeError("OpenWeatherMap API key is not configured in environment variable OWM_API_KEY")


def get_hourly_forecast(location: str, dt: datetime) -> Dict:
    """
    Retrieve hourly forecast for a given datetime and location using OpenWeatherMap.
    :param location: "lat,lon"
    :param dt: datetime for which to retrieve forecast
    """
    lat, lon = location.split(",")
    url = (
        f"https://api.openweathermap.org/data/2.5/onecall?exclude=current,minutely,daily,alerts&"
        f"lat={lat}&lon={lon}&appid={API_KEY}"
    )
    resp = requests.get(url)
    resp.raise_for_status()
    hourly = resp.json().get("hourly", [])
    target_ts = int(dt.timestamp())
    for hour in hourly:
        if abs(hour.get("dt") - target_ts) < 3600:
            return hour
    raise ValueError(f"No forecast available for {dt}")