from pydantic import BaseModel, Field, condecimal
from typing import List

class GeoPoint(BaseModel):
    latitude: condecimal(gt=-90, le=90)
    longitude: condecimal(gt=-180, le=180)

class RouteModel(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    route_name: str
    start_location: GeoPoint
    end_location: GeoPoint
    route_points: List[GeoPoint]