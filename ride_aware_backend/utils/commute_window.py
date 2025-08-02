from datetime import datetime, time, timedelta


def parse_time(time_str: str, fmt: str = "%H:%M") -> time:
    """
    Parse a time string into a time object.
    """
    return datetime.strptime(time_str, fmt).time()


def is_within_commute_window(dt: datetime, start: time, end: time) -> bool:
    """
    Check if a datetime falls within the commute window defined by start and end times.
    """
    t = dt.time()
    if start <= end:
        return start <= t <= end
    return t >= start or t <= end


def commute_window_duration(start: time, end: time) -> timedelta:
    """
    Compute the duration of the commute window between start and end times.
    """
    today = datetime.today()
    start_dt = datetime.combine(today, start)
    end_dt = datetime.combine(
        today + (timedelta(days=1) if end < start else timedelta()),
        end
    )
    return end_dt - start_dt