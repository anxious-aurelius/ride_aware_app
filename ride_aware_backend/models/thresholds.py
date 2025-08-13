from pydantic import BaseModel, Field, condecimal, StringConstraints, ConfigDict
from typing import Annotated, Optional

TimeStr = Annotated[str, StringConstraints(pattern=r"^\d{2}:\d{2}$")]
DateStr = Annotated[str, StringConstraints(pattern=r"^\d{4}-\d{2}-\d{2}$")]

class WeatherLimits(BaseModel):
    model_config = ConfigDict(extra="forbid")

    max_wind_speed: condecimal(gt=0, le=200)
    max_rain_intensity: condecimal(ge=0, le=50)
    max_humidity: condecimal(gt=0, le=100)
    min_temperature: condecimal(gt=-50, le=60)
    max_temperature: condecimal(gt=-50, le=60)
    headwind_sensitivity: condecimal(ge=0, le=50) = Field(default=20)
    crosswind_sensitivity: condecimal(ge=0, le=50) = Field(default=15)
    min_visibility: Optional[condecimal(gt=0, le=20000)] = None
    max_pollution: Optional[condecimal(gt=0, le=500)] = None
    max_uv_index: Optional[condecimal(gt=0, le=11)] = None

class OfficeLocation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    latitude: condecimal(gt=-90, le=90, decimal_places=6)
    longitude: condecimal(gt=-180, le=180, decimal_places=6)


class Thresholds(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(..., min_length=6, max_length=64)
    date: DateStr
    start_time: TimeStr
    end_time: TimeStr
    timezone: str = Field(default="UTC", min_length=1)
    weather_snapshot_interval_minutes: int = Field(default=10, ge=1)
    presence_radius_m: int = Field(default=100, ge=1)
    speed_cutoff_kmh: int = Field(default=5, ge=0)
    weather_limits: WeatherLimits
    office_location: OfficeLocation
