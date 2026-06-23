import time
import logging
from fastapi import APIRouter
from sqlalchemy import text

from app.database import AsyncSessionLocal
from app.cache import get_redis

router = APIRouter()
logger = logging.getLogger(__name__)

START_TIME = time.time()


@router.get("/health", summary="Full health check")
async def health_check():
    """
    Returns the health status of every component:
    - API itself
    - PostgreSQL connection
    - Redis connection
    """
    status = {"api": "ok", "postgres": "unknown", "redis": "unknown"}
    http_status = 200

    # ── PostgreSQL ─────────────────────────────────────────────────────────────
    try:
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
        status["postgres"] = "ok"
    except Exception as e:
        logger.error(f"Health check — postgres failed: {e}")
        status["postgres"] = "error"
        http_status = 503

    # ── Redis ──────────────────────────────────────────────────────────────────
    try:
        r = await get_redis()
        await r.ping()
        status["redis"] = "ok"
    except Exception as e:
        logger.error(f"Health check — redis failed: {e}")
        status["redis"] = "error"
        http_status = 503

    uptime_seconds = round(time.time() - START_TIME, 1)

    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=http_status,
        content={
            "status": "healthy" if http_status == 200 else "degraded",
            "uptime_seconds": uptime_seconds,
            "components": status,
        },
    )


@router.get("/health/live", summary="Liveness probe (k8s / Docker)")
async def liveness():
    """Lightweight — just confirms the process is alive."""
    return {"status": "alive"}


@router.get("/health/ready", summary="Readiness probe")
async def readiness():
    """Confirms the app is ready to receive traffic (DB must be reachable)."""
    try:
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=503, content={"status": "not ready"})
