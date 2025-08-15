# routes/weather_history.py
import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from services.weather_history_service import record_weather_ping

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/weatherHistory", tags=["weatherHistory"])


class WeatherPing(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    threshold_id: str = Field(..., min_length=1)
    lat: float
    lon: float
    timestamp: Optional[datetime] = None


@router.post("/ping")
async def ping(payload: WeatherPing):
    try:
        await record_weather_ping(
            device_id=payload.device_id,
            threshold_id=payload.threshold_id,
            lat=payload.lat,
            lon=payload.lon,
            timestamp=payload.timestamp,
        )
        return {"status": "ok"}
    except Exception as e:
        logger.exception("weather ping error")
        raise HTTPException(status_code=500, detail=str(e))
