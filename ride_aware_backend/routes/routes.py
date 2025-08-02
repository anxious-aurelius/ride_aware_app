from fastapi import APIRouter
from models.route import RouteModel
from controllers.route_controller import *

router = APIRouter(prefix="/routes", tags=["Routes"])


@router.post("",include_in_schema=False)
@router.post("/")
async def create_user_route(route: RouteModel):
    print(1)
    return await save_user_route(route)

@router.get("/{device_id}")
async def fetch_user_route(device_id: str):
    return await get_user_route(device_id)