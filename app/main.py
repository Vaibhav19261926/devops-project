import time
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.database import engine, Base
from app.cache import get_redis
from app.routers import items, health

#  Logging Setup 
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger(__name__)


# Lifespan (startup / shutdown)
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up — creating database tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database tables ready.")
    yield
    logger.info("Shutting down — closing connections...")
    await engine.dispose()


# App 
app = FastAPI(
    title="DevOps Demo API",
    description="A production-ready FastAPI service with PostgreSQL, Redis, and NGINX.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware 
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = round((time.time() - start) * 1000, 2)
    logger.info(
        f"{request.method} {request.url.path} → {response.status_code} ({duration}ms)"
    )
    return response


#  Routers 
app.include_router(health.router, tags=["Health"])
app.include_router(items.router, prefix="/api/v1", tags=["Items"])


# Root 
@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "DevOps Demo API is running 🚀",
        "docs": "/docs",
        "health": "/health",
    }
