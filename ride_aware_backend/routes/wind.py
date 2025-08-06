import logging
from typing import List

from fastapi import APIRouter

from controllers.wind_controller import compute_wind_directions
from models.wind import RouteRequest, WindResult

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Wind"])


@router.post("/wind-directions", response_model=List[WindResult])
async def wind_directions(route: RouteRequest):
    logger.info("Wind directions request with %s points", len(route.points))
    return await compute_wind_directions(route)
