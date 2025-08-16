from fastapi import APIRouter, Body
from controllers.feedback_controller import record_feedback

router = APIRouter()

@router.post("/feedback")
async def post_feedback(payload: dict = Body(...)):
    return await record_feedback(payload)
