import logging
from typing import Any, Dict, Type, TypeVar

from fastapi import HTTPException
from pymongo.collection import Collection

ModelT = TypeVar("ModelT")


async def fetch_by_device_id(
    collection: Collection,
    device_id: str,
    model_cls: Type[ModelT],
    not_found_msg: str,
    logger: logging.Logger,
) -> Dict[str, Any]:
    """Retrieve and validate a document by device_id."""
    col_name = getattr(collection, "name", collection.__class__.__name__)
    logger.info("Retrieving %s for device %s", col_name, device_id)
    doc = await collection.find_one({"device_id": device_id})
    if not doc:
        logger.warning("%s not found for device %s", col_name, device_id)
        raise HTTPException(status_code=404, detail=not_found_msg)
    doc.pop("_id", None)
    logger.debug("%s document for %s: %s", col_name, device_id, doc)
    return model_cls(**doc).model_dump(mode="json")


async def upsert_by_device_id(
    collection: Collection,
    data: Dict[str, Any],
    device_id: str,
    logger: logging.Logger,
) -> Dict[str, Any]:
    """Upsert a document identified by device_id."""
    col_name = getattr(collection, "name", collection.__class__.__name__)
    logger.info("Upserting %s for device %s", col_name, device_id)
    result = await collection.update_one(
        {"device_id": device_id},
        {"$set": data},
        upsert=True,
    )
    logger.debug(
        "Upsert result for %s in %s: modified=%s upserted_id=%s",
        device_id,
        col_name,
        getattr(result, "modified_count", None),
        getattr(result, "upserted_id", None),
    )
    return {
        "device_id": device_id,
        "status": "ok",
        "modified_count": getattr(result, "modified_count", None),
        "upserted_id": str(getattr(result, "upserted_id", "")) or None,
    }
