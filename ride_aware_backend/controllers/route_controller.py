from fastapi import HTTPException
from models.route import RouteModel
from services.db import routes_collection
from pymongo.errors import PyMongoError

async def save_user_route(route: RouteModel):
    try:
        result = await routes_collection.update_one(
            {"device_id": route.device_id},
            {"$set": route.model_dump(mode='json')},
            upsert=True
        )
        return {"status": "ok", "device_id": route.device_id}
    except PyMongoError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

async def get_user_route(device_id: str) -> dict:
    doc = await routes_collection.find_one({"device_id": device_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Route not found")

    doc.pop("_id", None)
    print(doc)
    return RouteModel(**doc).model_dump(mode="json")

