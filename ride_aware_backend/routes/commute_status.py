import logging

from fastapi import APIRouter, HTTPException
from controllers.commute_status_controller import get_status
from services.weather_service import MissingAPIKeyError


router = APIRouter(prefix="/commute", tags=["commute"])


@router.get("/status/{device_id}")
async def commute_status(device_id: str):
    """Return commute status for the specified device."""
    try:
        return await get_status(device_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    except MissingAPIKeyError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Internal server error")

