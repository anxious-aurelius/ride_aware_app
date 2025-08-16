import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from controllers.forecast_controller import (
    get_forecast,
    evaluate_route,
    get_next_hours,
)
from services.weather_service import MissingAPIKeyError
from models.thresholds import WeatherLimits

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["Forecast"])

@router.get("/forecast")
async def forecast(lat: float, lon: float, time: datetime):
    logger.info("Requesting forecast for lat=%s lon=%s at %s", lat, lon, time)
    try:
        return await get_forecast(lat, lon, time)
    except MissingAPIKeyError as e:
        logger.error("Weather service configuration error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
    except Exception:
        logger.exception("Unexpected error retrieving forecast")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/forecast/next")
async def forecast_next(lat: float, lon: float, hours: int = 6):
    logger.info(
        "Requesting next %s hours forecast for lat=%s lon=%s", hours, lat, lon
    )
    try:
        return await get_next_hours(lat, lon, hours)
    except MissingAPIKeyError as e:
        logger.error("Weather service configuration error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
    except Exception:
        logger.exception("Unexpected error retrieving forecast")
        raise HTTPException(status_code=500, detail="Internal server error")


class _Point(BaseModel):
    latitude: float
    longitude: float


class RouteForecastRequest(BaseModel):
    points: List[_Point]
    time: datetime
    thresholds: WeatherLimits


@router.post("/forecast/route")
async def forecast_route(req: RouteForecastRequest):
    logger.info("Route forecast request with %s points", len(req.points))
    try:
        pts = [p.dict() for p in req.points]
        return await evaluate_route(pts, req.time, req.thresholds)
    except MissingAPIKeyError as e:
        logger.error("Weather service configuration error: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
    except Exception:
        logger.exception("Unexpected error retrieving route forecast")
        raise HTTPException(status_code=500, detail="Internal server error")
