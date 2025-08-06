from pydantic import BaseModel, Field
from typing import List, Optional


class Coordinate(BaseModel):
    lat: float = Field(..., description="Latitude in decimal degrees")
    lon: float = Field(..., description="Longitude in decimal degrees")


class RouteRequest(BaseModel):
    points: List[Coordinate] = Field(
        ..., description="List of route coordinates (latitude & longitude)"
    )


class WindResult(BaseModel):
    lat: float
    lon: float
    wind_deg: Optional[float] = Field(
        None, description="Wind direction in degrees (0-360). None if data unavailable"
    )
