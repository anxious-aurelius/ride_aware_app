import logging
from fastapi import HTTPException
from models.thresholds import Thresholds
from services.db import thresholds_collection
from services.db_utils import fetch_by_device_id, upsert_by_device_id


logger = logging.getLogger(__name__)


async def upsert_threshold(threshold: Thresholds) -> dict:
    data = threshold.model_dump(mode="json")
    device_id = data["device_id"]
    return await upsert_by_device_id(
        thresholds_collection, data, device_id, logger
    )


async def get_thresholds(device_id: str) -> dict:
    return await fetch_by_device_id(
        thresholds_collection,
        device_id,
        Thresholds,
        "Thresholds not found",
        logger,
    )

