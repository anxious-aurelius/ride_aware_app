import logging
import os
from datetime import datetime
from math import radians, sin, cos, sqrt, asin
from typing import List, Optional

import httpx

from models.wind import Coordinate, RouteRequest, WindResult
from services.db import db

logger = logging.getLogger(__name__)

wind_collection = db["wind_directions"]


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    c = 2 * asin(sqrt(a))
    return R * c


def sample_route_points(points: List[Coordinate]) -> List[Coordinate]:
    sampled: List[Coordinate] = []
    if not points or len(points) < 2:
        return sampled
    distance_so_far = 0.0
    next_sample_distance = 1000.0
    for i in range(len(points) - 1):
        start = points[i]
        end = points[i + 1]
        segment_distance = haversine_distance(start.lat, start.lon, end.lat, end.lon)
        while distance_so_far + segment_distance >= next_sample_distance:
            distance_into_segment = next_sample_distance - distance_so_far
            ratio = distance_into_segment / segment_distance
            sample_lat = start.lat + ratio * (end.lat - start.lat)
            sample_lon = start.lon + ratio * (end.lon - start.lon)
            sampled.append(Coordinate(lat=sample_lat, lon=sample_lon))
            next_sample_distance += 1000.0
        distance_so_far += segment_distance
    return sampled


async def get_wind_direction(lat: float, lon: float) -> Optional[float]:
    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        logger.warning("OPENWEATHER_API_KEY environment variable not set")
        return None
    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {"lat": lat, "lon": lon, "appid": api_key}
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            resp = await client.get(url, params=params)
        if resp.status_code != 200:
            logger.warning(
                "Wind API request failed for (%s,%s) with status %s",
                lat,
                lon,
                resp.status_code,
            )
            return None
        data = resp.json()
        return data.get("wind", {}).get("deg")
    except Exception as e:
        logger.warning("Error fetching wind data for (%s,%s): %s", lat, lon, e)
        return None


async def compute_wind_directions(req: RouteRequest) -> List[WindResult]:
    sample_points = sample_route_points(req.points)
    if req.points:
        last = req.points[-1]
        if sample_points:
            if (
                haversine_distance(
                    sample_points[-1].lat, sample_points[-1].lon, last.lat, last.lon
                )
                > 500
            ):
                sample_points.append(last)
        else:
            sample_points.append(last)

    results: List[WindResult] = []
    for coord in sample_points:
        wind_deg = await get_wind_direction(coord.lat, coord.lon)
        if wind_deg is not None:
            results.append(WindResult(lat=coord.lat, lon=coord.lon, wind_deg=wind_deg))

    record = {
        "route_points": [
            {"lat": p.lat, "lon": p.lon} for p in req.points
        ],
        "sampled_winds": [r.dict() for r in results],
        "timestamp": datetime.utcnow(),
    }
    try:
        await wind_collection.insert_one(record)
    except Exception as e:
        logger.warning("Failed to store wind data: %s", e)

    return results
