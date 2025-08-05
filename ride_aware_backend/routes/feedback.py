import logging
from fastapi import APIRouter
from models.feedback import Feedback
from controllers.feedback_controller import save_feedback

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/feedback", tags=["Feedback"])


@router.post("", include_in_schema=False)
@router.post("/")
async def submit_feedback(feedback: Feedback):
    logger.info(
        "Received feedback for device %s on threshold %s",
        feedback.device_id,
        feedback.threshold_id,
    )
    return await save_feedback(feedback)
