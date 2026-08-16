from fastapi import FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.database import engine


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
)


@app.get("/")
def root():
    return {
        "application": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
        "status": "running",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
    }


@app.get("/health/database")
def database_health_check():
    try:
        with Session(engine) as db:
            db.execute(text("SELECT 1"))

        return {
            "status": "healthy",
            "database": "connected",
        }

    except Exception:
        return {
            "status": "unhealthy",
            "database": "unavailable",
        }