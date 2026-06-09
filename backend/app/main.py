from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.api.routes import auth, protocols, checkins, labs, insights, health, wearables, notifications, waitlist, feedback

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    description="Personalized peptide protocol engine API",
    version="0.1.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

_cors_origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
if settings.debug:
    _cors_origins.append("*")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

# Include routers
app.include_router(health.router, tags=["health"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(protocols.router, prefix="/api/v1/protocols", tags=["protocols"])
app.include_router(checkins.router, prefix="/api/v1/checkins", tags=["checkins"])
app.include_router(labs.router, prefix="/api/v1/labs", tags=["labs"])
app.include_router(insights.router, prefix="/api/v1/insights", tags=["insights"])
app.include_router(wearables.router, prefix="/api/v1/wearables", tags=["wearables"])
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["notifications"])
app.include_router(waitlist.router, prefix="/api/v1/waitlist", tags=["waitlist"])
app.include_router(feedback.router, prefix="/api/v1/feedback", tags=["feedback"])


@app.on_event("startup")
async def startup_event():
    pass


@app.on_event("shutdown")
async def shutdown_event():
    pass
