import json
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.cache import get_redis
from app.models.item import Item
from app.schemas.item import ItemCreate, ItemUpdate, ItemResponse

router = APIRouter()
logger = logging.getLogger(__name__)

CACHE_TTL = 60  # seconds


@router.get("/items", response_model=list[ItemResponse], summary="List all items")
async def list_items(
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Item).where(Item.is_active == True).offset(skip).limit(limit)
    )
    return result.scalars().all()


@router.post("/items", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
async def create_item(payload: ItemCreate, db: AsyncSession = Depends(get_db)):
    item = Item(**payload.model_dump())
    db.add(item)
    await db.flush()
    await db.refresh(item)
    logger.info(f"Created item id={item.id} title={item.title!r}")

    # Invalidate list cache
    r = await get_redis()
    await r.delete("items:all")

    return item


@router.get("/items/{item_id}", response_model=ItemResponse)
async def get_item(item_id: int, db: AsyncSession = Depends(get_db)):
    cache_key = f"items:{item_id}"
    r = await get_redis()

    # ── Try cache first ────────────────────────────────────────────────────────
    cached = await r.get(cache_key)
    if cached:
        logger.info(f"Cache HIT for item {item_id}")
        return json.loads(cached)

    # ── Fallback to DB ─────────────────────────────────────────────────────────
    item = await db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    response = ItemResponse.model_validate(item)
    await r.setex(cache_key, CACHE_TTL, response.model_dump_json())
    logger.info(f"Cache MISS — stored item {item_id} in Redis")
    return response


@router.patch("/items/{item_id}", response_model=ItemResponse)
async def update_item(
    item_id: int, payload: ItemUpdate, db: AsyncSession = Depends(get_db)
):
    item = await db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, field, value)

    await db.flush()
    await db.refresh(item)

    # Invalidate cache
    r = await get_redis()
    await r.delete(f"items:{item_id}", "items:all")

    return item


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(item_id: int, db: AsyncSession = Depends(get_db)):
    item = await db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    item.is_active = False  # soft delete
    await db.flush()

    r = await get_redis()
    await r.delete(f"items:{item_id}", "items:all")
    logger.info(f"Soft-deleted item id={item_id}")
