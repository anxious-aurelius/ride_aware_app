import logging
from fastapi import APIRouter
from models.route import RouteModel
from controllers.route_controller import save_user_route, get_user_route


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/routes", tags=["Routes"])


@router.post("", include_in_schema=False)
@router.post("/")
async def create_user_route(route: RouteModel):
    logger.info("Saving route for device %s", route.device_id)
    return await save_user_route(route)


@router.get("/{device_id}")
async def fetch_user_route(device_id: str):
    logger.info("Fetching route for device %s", device_id)
    return await get_user_route(device_id)
