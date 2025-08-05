from datetime import date
from typing import Dict, Optional
from pydantic import BaseModel, Field

class RideHistoryEntry(BaseModel):
    device_id: str = Field(..., min_length=6, max_length=64)
    date: date
    start_time: str
    end_time: str
    status: str
    summary: Dict[str, object]
    feedback: Optional[str] = None
