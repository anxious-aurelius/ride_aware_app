import logging
from motor.motor_asyncio import AsyncIOMotorClient
from config import MONGO_URI

logger = logging.getLogger(__name__)

client = AsyncIOMotorClient(MONGO_URI)
logger.info("Connected to MongoDB at %s", MONGO_URI)
db = client["acs"]

thresholds_collection = db["thresholds"]
routes_collection = db["routes"]
fcm_tokens_collection = db["fcm_tokens"]
feedback_collection = db["feedback"]
ride_history_collection = db["ride_history"]
forecasts_collection = db["forecasts"]
weather_history_collection = db["weather_history"]


async def _ensure_index(coll, keys, **kwargs):
    try:
        name = await coll.create_index(keys, **kwargs)
        logger.info("Ensured index on %s: %s", coll.name, name)
        return name
    except Exception as e:
        logger.warning("create_index on %s failed: %s", coll.name, e)


async def init_db() -> None:
    await _ensure_index(
        thresholds_collection,
        [("device_id", 1), ("date", 1), ("start_time", 1), ("end_time", 1)],
        unique=True,
        name="uniq_threshold_device_date_start_end",
    )
    await _ensure_index(
        thresholds_collection,
        [("device_id", 1), ("date", -1), ("start_time", -1)],
        name="idx_threshold_device_date_start_desc",
    )
    await _ensure_index(
        feedback_collection,
        [("threshold_id", 1)],
        unique=True,
        name="uniq_feedback_threshold",
        partialFilterExpression={"threshold_id": {"$exists": True}},
    )

    await _ensure_index(
        ride_history_collection,
        [("threshold_id", 1), ("date", 1), ("start_time", 1)],
        unique=True,
        name="uniq_ride_threshold_date_start",
    )
    await _ensure_index(
        ride_history_collection,
        [("device_id", 1), ("date", -1)],
        name="idx_ride_device_date_desc",
    )

    await _ensure_index(
        weather_history_collection,
        [("threshold_id", 1), ("timestamp", 1)],
        name="idx_weather_threshold_ts",
    )

    await _ensure_index(routes_collection, [("device_id", 1)], name="idx_route_device")
