from typing import Optional, Dict, Any
from datetime import date
from pydantic import BaseModel, Field

class RideHistoryEntry(BaseModel):
    device_id: str
    threshold_id: str
    date: date
    start_time: str
    end_time: str
    status: str = "pending"

    # Single textual field shown to the user
    feedback_summary: Optional[str] = None

    # Optional computed metrics bucket (keep, but you can ignore in UI)
    summary: Dict[str, Any] = Field(default_factory=dict)

    # Snapshot of the thresholds used at the time
    threshold: Dict[str, Any] = Field(default_factory=dict)

    # Not stored by save_ride; attached ad-hoc by fetch_rides
    weather_history: Optional[list] = None
