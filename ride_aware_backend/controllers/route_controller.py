import logging
from fastapi import HTTPException
from models.route import RouteModel
from services.db import routes_collection
from services.db_utils import fetch_by_device_id, upsert_by_device_id
from pymongo.errors import PyMongoError


logger = logging.getLogger(__name__)


async def save_user_route(route: RouteModel):
    data = route.model_dump(mode="json")
    try:
        await upsert_by_device_id(routes_collection, data, route.device_id, logger)
        return {"status": "ok", "device_id": route.device_id}
    except PyMongoError as e:
        logger.error("Database error saving route for %s: %s", route.device_id, e)
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


async def get_user_route(device_id: str) -> dict:
    return await fetch_by_device_id(
        routes_collection,
        device_id,
        RouteModel,
        "Route not found",
        logger,
    )


