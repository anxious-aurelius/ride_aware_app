# routes/thresholds.py
from fastapi import APIRouter, HTTPException
from models.thresholds import Thresholds
from controllers.thresholds_controller import (
    upsert_threshold,
    get_thresholds,
    get_current_threshold,
)

router = APIRouter()


@router.post("/thresholds")
async def post_thresholds(payload: Thresholds):
    try:
        return await upsert_threshold(payload)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/thresholds/{device_id}")
async def get_current(device_id: str):
    return await get_current_threshold(device_id)


@router.get("/thresholds/{device_id}/{date}/{start_time}/{end_time}")
async def get_exact(device_id: str, date: str, start_time: str, end_time: str):
    return await get_thresholds(device_id, date, start_time, end_time)
