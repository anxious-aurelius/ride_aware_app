import logging
from fastapi import FastAPI
from routes import (
    thresholds,
    routes,
    fcm,
    commute_status,
    forecast,
    feedback,
    ride_history,
    wind,
)
from services.db import init_db
from services.alert_service import schedule_existing_alerts


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI()
logger.info("FastAPI application initialized")
app.include_router(thresholds.router)
app.include_router(routes.router)
app.include_router(fcm.router)
app.include_router(commute_status.router)
app.include_router(forecast.router)
app.include_router(feedback.router)
app.include_router(ride_history.router)
app.include_router(wind.router)


@app.on_event("startup")
async def startup_event():
    await init_db()
    await schedule_existing_alerts()
