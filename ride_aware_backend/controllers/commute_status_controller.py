import logging
from services.commute_status_service import get_commute_status


logger = logging.getLogger(__name__)


async def get_status(device_id: str) -> dict:
    """Controller layer for commute status retrieval."""
    logger.info("Getting commute status for device %s", device_id)
    return await get_commute_status(device_id)

