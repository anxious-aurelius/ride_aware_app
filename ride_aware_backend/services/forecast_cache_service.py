from __future__ import annotations

from datetime import datetime
from typing import List, Dict

from .db import forecasts_collection

async def save_hourly_forecasts(lat: float, lon: float, forecasts: List[Dict]) -> None:
    """Store forecasts in the database with metadata."""
    doc = {
        "lat": lat,
        "lon": lon,
        "created_at": datetime.now(),
        "forecasts": forecasts,
    }
    await forecasts_collection.insert_one(doc)
