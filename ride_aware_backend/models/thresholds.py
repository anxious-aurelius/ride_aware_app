from pydantic import BaseModel, Field, condecimal, StringConstraints
from typing import Annotated, Optional

TimeStr = Annotated[str, StringConstraints(pattern=r"^\d{2}:\d{2}$")]

class WeatherLimits(BaseModel):
    max_wind_speed: condecimal(gt=0, le=200)
    max_rain_intensity: condecimal(ge=0, le=50)
    max_humidity: condecimal(gt=0, le=100)
    min_temperature: condecimal(gt=-50, le=60)
    max_temperature: condecimal(gt=-50, le=60)
    headwind_sensitivity: condecimal(ge=0, le=50) = Field(default=20)
    crosswind_sensitivity: condecimal(ge=0, le=50) = Field(default=15)

class EnvironmentalRisk(BaseModel):
    min_visibility: condecimal(gt=0, le=20000)
    max_pollution: condecimal(gt=0, le=500)
    max_uv_index: condecimal(gt=0, le=11)

class OfficeLocation(BaseModel):
    latitude: condecimal(gt=-90, le=90, decimal_places=6)
    longitude: condecimal(gt=-180, le=180, decimal_places=6)

class CommuteWindows(BaseModel):
    morning: TimeStr
    evening: TimeStr


class Thresholds(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    weather_limits: WeatherLimits
    environmental_risk: EnvironmentalRisk
    office_location: OfficeLocation
    commute_windows: Optional[CommuteWindows] = None
