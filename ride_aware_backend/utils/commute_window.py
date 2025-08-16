from datetime import datetime, time
import logging


logger = logging.getLogger(__name__)


def parse_time(time_str: str, fmt: str = "%H:%M") -> time:
    parsed = datetime.strptime(time_str, fmt).time()
    logger.debug("Parsed time '%s' using format '%s' into %s", time_str, fmt, parsed)
    return parsed