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

    feedback_summary: Optional[str] = None

    summary: Dict[str, Any] = Field(default_factory=dict)

    threshold: Dict[str, Any] = Field(default_factory=dict)

    weather_history: Optional[list] = None
