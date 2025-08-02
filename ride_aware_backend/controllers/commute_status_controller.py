from services.commute_status_service import get_commute_status
from models.thresholds import Thresholds


def get_status(thresholds: Thresholds) -> dict:
    """
    Controller function: orchestrates service call and allows exceptions to bubble up
    to the route layer for HTTP translation.
    """
    return get_commute_status(thresholds)