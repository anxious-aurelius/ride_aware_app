from datetime import datetime
from pydantic import BaseModel, Field
from typing import Literal, Optional


class Feedback(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    threshold_id: str = Field(..., min_length=1)
    commute: Literal["start", "end"]
    temperature_ok: bool
    wind_speed_ok: bool
    headwind_ok: bool
    crosswind_ok: bool
    precipitation_ok: bool
    humidity_ok: bool
    summary: Optional[str] = None


class RideFeedback(BaseModel):
    """Represents a ride feedback entry awaiting user input."""

    device_id: str = Field(..., min_length=6, max_length=64)
    threshold_id: str = Field(..., min_length=1)
    created_at: datetime
    commute: Optional[Literal["start", "end"]] = None
    temperature_ok: Optional[bool] = None
    wind_speed_ok: Optional[bool] = None
    headwind_ok: Optional[bool] = None
    crosswind_ok: Optional[bool] = None
    precipitation_ok: Optional[bool] = None
    humidity_ok: Optional[bool] = None
    summary: Optional[str] = None
