from datetime import datetime
from typing import Dict
from pydantic import BaseModel, Field


class RouteWeatherSnapshot(BaseModel):
    """Represents stored weather data for a ride segment."""

    device_id: str = Field(..., min_length=6, max_length=64)
    threshold_id: str = Field(..., min_length=1)
    timestamp: datetime
    weather: Dict[str, object]
