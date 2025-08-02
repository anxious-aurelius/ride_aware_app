from fastapi import APIRouter, HTTPException
from controllers.commute_status_controller import get_status
from models.thresholds import Thresholds

router = APIRouter(prefix="/commute", tags=["commute"])

@router.post("/status")
def commute_status(thresholds: Thresholds):
    """
    Route handler: delegates to controller and converts exceptions into HTTP errors.
    """
    try:
        return get_status(thresholds)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Internal server error")