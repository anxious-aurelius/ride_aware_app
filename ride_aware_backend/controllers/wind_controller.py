import logging
from typing import List

from models.wind import RouteRequest, WindResult
from services.wind_service import compute_wind_directions as compute_wind_directions_service

logger = logging.getLogger(__name__)


async def compute_wind_directions(req: RouteRequest) -> List[WindResult]:
    logger.info("Computing wind directions for %s points", len(req.points))
    return await compute_wind_directions_service(req)
