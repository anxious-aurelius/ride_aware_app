import logging
from fastapi import APIRouter, Request
from models.thresholds import Thresholds
from controllers.threshold_controller import upsert_threshold, get_thresholds


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/thresholds", tags=["Thresholds"])


@router.post("", include_in_schema=False)
@router.post("/")
async def set_threshold(threshold: Thresholds, request: Request):
    body = await request.json()
    logger.debug("Incoming payload: %s", body)
    logger.info(
        "Setting thresholds for device %s on %s at %s",
        threshold.device_id,
        threshold.date,
        threshold.start_time,
    )
    return await upsert_threshold(threshold)


@router.get("/{device_id}/{date}/{start_time}")
async def fetch_threshold(device_id: str, date: str, start_time: str):
    logger.info(
        "Fetching thresholds for device %s on %s at %s", device_id, date, start_time
    )
    return await get_thresholds(device_id, date, start_time)

