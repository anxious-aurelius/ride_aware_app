from pydantic import BaseModel, Field
from typing import Literal


class Feedback(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    commute_time: Literal["morning", "evening"]
    temperature_ok: bool
    wind_speed_ok: bool
    headwind_ok: bool
    crosswind_ok: bool
    precipitation_ok: bool
    humidity_ok: bool
