from datetime import date
from typing import Dict, Optional, List
from pydantic import BaseModel, Field

class RideHistoryEntry(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    threshold_id: str = Field(..., min_length=1)
    date: date
    start_time: str
    end_time: str
    status: str
    summary: Dict[str, object]
    feedback: Optional[str] = None
    weather_history: Optional[List[Dict[str, object]]] = None
