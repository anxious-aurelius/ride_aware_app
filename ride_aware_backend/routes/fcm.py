from fastapi import APIRouter
from models.fcm import FCMDeviceModel
from services.db import fcm_tokens_collection

router = APIRouter(prefix="/fcm", tags=["FCM"])

@router.post("/register/")
async def register_fcm_token(data: FCMDeviceModel):
    await fcm_tokens_collection.update_one(
        {"device_id": data.device_id},
        {"$set": {"fcm_token": data.fcm_token}},
        upsert=True
    )
    return {"status": "success", "message": "FCM token registered."}
