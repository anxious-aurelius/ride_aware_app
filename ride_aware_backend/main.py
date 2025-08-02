from fastapi import FastAPI
from routes import thresholds, routes, fcm, commute_status

app = FastAPI()
app.include_router(thresholds.router)
app.include_router(routes.router)
app.include_router(fcm.router)
app.include_router(commute_status.router)