import logging
from fastapi import APIRouter
from models.fcm import FCMDeviceModel
from services.db import fcm_tokens_collection


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/fcm", tags=["FCM"])


@router.post("/register/")
async def register_fcm_token(data: FCMDeviceModel):
    logger.info("Registering FCM token for device %s", data.device_id)
    await fcm_tokens_collection.update_one(
        {"device_id": data.device_id},
        {"$set": {"fcm_token": data.fcm_token}},
        upsert=True,
    )
    logger.debug("FCM token stored for device %s", data.device_id)
    return {"status": "success", "message": "FCM token registered."}

