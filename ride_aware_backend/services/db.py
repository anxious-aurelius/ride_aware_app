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
