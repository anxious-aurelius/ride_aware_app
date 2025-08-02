from fastapi import HTTPException
from models.thresholds import Thresholds
from services.db import thresholds_collection

from fastapi import HTTPException
from models.thresholds import Thresholds
from services.db import thresholds_collection

async def upsert_threshold(threshold: Thresholds) -> dict:
    data = threshold.model_dump(mode="json")
    device_id = data["device_id"]

    result = await thresholds_collection.update_one(
        {"device_id": device_id},
        {"$set": data},
        upsert=True
    )

    return {
        "device_id": device_id,
        "status": "ok",
        "modified_count": result.modified_count,
        "upserted_id": str(result.upserted_id) if result.upserted_id else None
    }


async def get_thresholds(device_id: str) -> dict:
    doc = await thresholds_collection.find_one({"device_id": device_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Thresholds not found")

    # Remove _id and validate through model
    doc.pop("_id", None)
    return Thresholds(**doc).model_dump(mode="json")
