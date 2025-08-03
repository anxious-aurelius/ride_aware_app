import logging
from fastapi import FastAPI
from routes import thresholds, routes, fcm, commute_status


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
