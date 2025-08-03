import pytest
from pydantic import ValidationError

from models.fcm import FCMDeviceModel
from models.route import RouteModel, GeoPoint
from models.thresholds import Thresholds, WeatherLimits, OfficeLocation


def test_fcm_device_model_valid():
    model = FCMDeviceModel(device_id="abc123", fcm_token="token")
    assert model.device_id == "abc123"


def test_fcm_device_model_invalid():
    with pytest.raises(ValidationError):
        FCMDeviceModel(device_id="abc123")


def test_route_model_validation():
    route = RouteModel(
        device_id="device123",
        route_name="Route",
        start_location=GeoPoint(latitude=0, longitude=0),
        end_location=GeoPoint(latitude=1, longitude=1),
        route_points=[GeoPoint(latitude=0, longitude=0)],
    )
    assert route.device_id == "device123"


def test_route_model_invalid_latitude():
    with pytest.raises(ValidationError):
        RouteModel(
            device_id="device123",
            route_name="Route",
            start_location=GeoPoint(latitude=100, longitude=0),
            end_location=GeoPoint(latitude=1, longitude=1),
            route_points=[],
        )


def test_thresholds_model_valid():
    thresholds = Thresholds(
        device_id="device123",
        weather_limits=WeatherLimits(
            max_wind_speed=10,
            max_rain_intensity=5,
            max_humidity=80,
            min_temperature=0,
            max_temperature=35,
            min_visibility=1000,
            max_pollution=100,
            max_uv_index=8,
        ),
        office_location=OfficeLocation(latitude=0, longitude=0),
    )
    assert thresholds.device_id == "device123"


def test_thresholds_model_invalid_device_id():
    with pytest.raises(ValidationError):
        Thresholds(
            device_id="dev",
            weather_limits=WeatherLimits(
                max_wind_speed=10,
                max_rain_intensity=5,
                max_humidity=80,
                min_temperature=0,
                max_temperature=35,
                min_visibility=1000,
                max_pollution=100,
                max_uv_index=8,
            ),
            office_location=OfficeLocation(latitude=0, longitude=0),
        )
