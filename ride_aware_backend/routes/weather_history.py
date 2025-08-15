# routes/weather_history.py
import logging
from fastapi import APIRouter, Body
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

from services.weather_history_service import record_snapshot_from_device

router = APIRouter(prefix="/weatherHistory", tags=["weather-history"])
logger = logging.getLogger(__name__)


class PingPayload(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    threshold_id: str = Field(..., min_length=1)
    lat: float
    lon: float
    timestamp: Optional[datetime] = None


@router.post("/ping")
async def weather_ping(payload: PingPayload = Body(...)):
    await record_snapshot_from_device(
        device_id=payload.device_id,
        threshold_id=payload.threshold_id,
        lat=payload.lat,
        lon=payload.lon,
        when=payload.timestamp,
    )
    return {"status": "ok"}
