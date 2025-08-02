from motor.motor_asyncio import AsyncIOMotorClient
from config import MONGO_URI

client = AsyncIOMotorClient(MONGO_URI)
db = client['acs']

thresholds_collection = db["thresholds"]
routes_collection = db["routes"]
fcm_tokens_collection = db["fcm_tokens"]