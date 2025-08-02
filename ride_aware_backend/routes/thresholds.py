from fastapi import APIRouter
from controllers.threshold_controller import *

router = APIRouter(prefix="/thresholds", tags=["Thresholds"])

@router.post("", include_in_schema=False)
@router.post("/")
async def set_threshold(threshold: Thresholds):
    return await upsert_threshold(threshold)

@router.get("/{device_id}")
async def fetch_threshold(device_id: str):
    return await get_thresholds(device_id)
