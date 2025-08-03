import logging
from fastapi import APIRouter
from models.thresholds import Thresholds
from controllers.threshold_controller import upsert_threshold, get_thresholds


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/thresholds", tags=["Thresholds"])


@router.post("", include_in_schema=False)
@router.post("/")
async def set_threshold(threshold: Thresholds):
    logger.info("Setting thresholds for device %s", threshold.device_id)
    return await upsert_threshold(threshold)


@router.get("/{device_id}")
async def fetch_threshold(device_id: str):
    logger.info("Fetching thresholds for device %s", device_id)
    return await get_thresholds(device_id)

