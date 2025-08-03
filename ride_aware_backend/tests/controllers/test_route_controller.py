import asyncio
import pytest
from unittest.mock import AsyncMock

from controllers import route_controller
from models.route import RouteModel, GeoPoint


def test_save_user_route(monkeypatch):
    route = RouteModel(
        device_id="device123",
        route_name="Route",
        start_location=GeoPoint(latitude=1, longitude=2),
        end_location=GeoPoint(latitude=3, longitude=4),
        route_points=[GeoPoint(latitude=1, longitude=2)],
    )

    dummy_result = object()
    collection = type("C", (), {"update_one": AsyncMock(return_value=dummy_result)})()
    monkeypatch.setattr(route_controller, "routes_collection", collection)

    result = asyncio.run(route_controller.save_user_route(route))
    collection.update_one.assert_called_once()
    assert result == {"status": "ok", "device_id": "device123"}


def test_get_user_route(monkeypatch):
    doc = {
        "device_id": "device123",
        "route_name": "Route",
        "start_location": {"latitude": 1, "longitude": 2},
        "end_location": {"latitude": 3, "longitude": 4},
        "route_points": [{"latitude": 1, "longitude": 2}],
    }
    collection = type("C", (), {"find_one": AsyncMock(return_value=doc)})()
    monkeypatch.setattr(route_controller, "routes_collection", collection)
    result = asyncio.run(route_controller.get_user_route("device123"))
    assert result["device_id"] == "device123"


def test_get_user_route_not_found(monkeypatch):
    collection = type("C", (), {"find_one": AsyncMock(return_value=None)})()
    monkeypatch.setattr(route_controller, "routes_collection", collection)
    with pytest.raises(route_controller.HTTPException):
        asyncio.run(route_controller.get_user_route("device123"))
