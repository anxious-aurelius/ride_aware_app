from pydantic import BaseModel

class FCMDeviceModel(BaseModel):
    device_id: str
    fcm_token: str
