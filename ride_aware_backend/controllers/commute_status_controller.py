from services.commute_status_service import get_commute_status


async def get_status(device_id: str) -> dict:
    """Controller layer for commute status retrieval."""
    return await get_commute_status(device_id)