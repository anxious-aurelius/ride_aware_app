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


async def init_db() -> None:
    """Initialize database indexes."""
    await thresholds_collection.create_index(
        [
            ("device_id", 1),
            ("date", 1),
            ("start_time", 1),
        ],
        unique=True,
    )
    await feedback_collection.create_index(
        "threshold_id",
        unique=True,
        partialFilterExpression={"threshold_id": {"$exists": True}}
    )
    await ride_history_collection.create_index(
        [("date", 1), ("threshold_id", 1)], unique=True
    )
    await weather_history_collection.create_index(
        [
            ("threshold_id", 1),
            ("timestamp", 1),
        ]
    )
