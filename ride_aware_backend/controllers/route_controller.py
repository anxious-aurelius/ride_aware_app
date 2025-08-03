import logging
from fastapi import HTTPException
from models.route import RouteModel
from services.db import routes_collection
from pymongo.errors import PyMongoError


logger = logging.getLogger(__name__)


async def save_user_route(route: RouteModel):
    try:
        await routes_collection.update_one(
            {"device_id": route.device_id},
            {"$set": route.model_dump(mode='json')},
            upsert=True,
        )
        logger.info("Route upserted for device %s", route.device_id)
        return {"status": "ok", "device_id": route.device_id}
    except PyMongoError as e:
        logger.error("Database error saving route for %s: %s", route.device_id, e)
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


async def get_user_route(device_id: str) -> dict:
    logger.info("Retrieving route for device %s", device_id)
    doc = await routes_collection.find_one({"device_id": device_id})
    if not doc:
        logger.warning("Route not found for device %s", device_id)
        raise HTTPException(status_code=404, detail="Route not found")

    doc.pop("_id", None)
    logger.debug("Route document for %s: %s", device_id, doc)
    return RouteModel(**doc).model_dump(mode="json")


