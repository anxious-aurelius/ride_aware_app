from fastapi import APIRouter, Body
from controllers.feedback_controller import record_feedback

router = APIRouter()

@router.post("/feedback")
async def post_feedback(payload: dict = Body(...)):
    """
    Accepts the feedback payload (must include device_id, threshold_id).
    Persists feedback and updates ride_history status/summary.
    """
    return await record_feedback(payload)
