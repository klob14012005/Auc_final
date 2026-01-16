from fastapi import FastAPI, Query
from typing import List, Optional
from db.models import get_lots_with_sellers, get_lot_by_id, get_bids_by_lot
from analytics.reports import average_lot_price, top_active_lots
from db.models import get_all_users, get_user_by_id, get_user_bids
from fastapi import HTTPException, Body
from db.schemas import UserModel, BidModel, LotInBidModel, LotCreateModel, LotUpdateModel, BidCreateModel
from typing import List
from analytics.reports import top_sellers, average_lot_duration, payment_stats
from db.models import get_lot_by_id, get_connection
from uuid import uuid4
from db.models import get_max_bid_for_lot
from db.models import (
    get_top_sellers,
    get_lot_durations,
    get_payment_stats
)
from db.schemas import (
    TopSellerModel,
    LotDurationModel,
    PaymentStatsModel
)



app = FastAPI(title="Auction Data Service")

@app.get("/lots")
def api_get_lots(
    state: Optional[List[str]] = Query(None, description="Состояние лота: DRAFT, ACTIVE, CLOSED, CANCELLED"),
    seller_id: Optional[str] = Query(None, description="ID продавца"),
    min_amount: Optional[float] = Query(None, description="Минимальная ставка лота"),
    max_amount: Optional[float] = Query(None, description="Максимальная ставка лота"),
    created_from: Optional[str] = Query(None, description="Дата создания с (YYYY-MM-DD)"),
    created_to: Optional[str] = Query(None, description="Дата создания по (YYYY-MM-DD)"),
    max_bid: Optional[float] = Query(None, description="Максимальная текущая ставка лота"),
    search: Optional[str] = Query(None, description="Поиск по ключевым словам в названии/описании"),
    order_by: Optional[str] = Query("created_at", description="Поле сортировки: created_at, minimum_bet_amount, name, state, max_bid"),
    order_dir: Optional[str] = Query("DESC", description="Направление сортировки: ASC или DESC")
):
    lots = get_lots_with_sellers(
        state=state,
        seller_id=seller_id,
        min_amount=min_amount,
        max_amount=max_amount,
        created_from=created_from,
        created_to=created_to,
        max_bid=max_bid,
        search=search,
        order_by=order_by,
        order_dir=order_dir
    )
    return lots

@app.get("/lots/{lot_id}")
def api_get_lot(lot_id: str):
    lot = get_lot_by_id(lot_id)
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")
    return lot

@app.get("/lots/{lot_id}/bids")
def api_get_lot_bids(lot_id: str):
    bids = get_bids_by_lot(lot_id)
    return bids

@app.get("/analytics/average-lot-price")
def api_average_lot_price():
    return {"average_price": average_lot_price()}

@app.get("/analytics/top-lots")
def api_top_lots(n: int = 5):
    return top_active_lots(n)

# ===== Пользователи =====

@app.get("/users", response_model=List[UserModel])
def api_get_users():
    """
    Возвращает список всех пользователей.
    """
    return get_all_users()

@app.get("/users/{user_id}", response_model=UserModel)
def api_get_user(user_id: str):
    """
    Возвращает данные одного пользователя.
    """
    user = get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.get("/users/{user_id}/bids", response_model=List[BidModel])
def api_get_user_bids(user_id: str):
    """
    Возвращает все ставки пользователя с данными о лотах.
    """
    user = get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    bids = get_user_bids(user_id)
    return bids


@app.get("/analytics/top-sellers")
def api_top_sellers(limit: int = 5):
    """
    Топ продавцов по сумме выигранных лотов
    """
    return top_sellers(limit)

@app.get("/analytics/average-lot-duration")
def api_average_lot_duration():
    """
    Среднее время жизни лота в днях
    """
    return {"average_duration_days": average_lot_duration()}

@app.get("/analytics/payment-stats")
def api_payment_stats():
    """
    Статистика по платежам: количество и процент по статусам
    """
    return payment_stats()


# ------------------- CREATE Лот -------------------
@app.post("/lots")
def create_lot(lot: LotCreateModel, seller_id: str = Body(...)):
    conn = get_connection()
    cur = conn.cursor()
    new_id = str(uuid4())
    cur.execute("""
        INSERT INTO lot (id, name, description, state, seller_id, minimum_bet_amount, active_till)
        VALUES (%s, %s, %s, 'DRAFT', %s, %s, %s)
        RETURNING id, name, description, state, seller_id, minimum_bet_amount, active_till;
    """, (new_id, lot.name, lot.description, seller_id, lot.minimum_bet_amount, lot.active_till))
    created_lot = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return created_lot

# ------------------- READ / GET Лот -------------------
@app.get("/lots/{lot_id}")
def read_lot(lot_id: str):
    lot = get_lot_by_id(lot_id)
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")
    return lot

# ------------------- UPDATE Лот -------------------
@app.put("/lots/{lot_id}")
def update_lot(lot_id: str, lot_update: LotUpdateModel):
    existing = get_lot_by_id(lot_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Lot not found")

    conn = get_connection()
    cur = conn.cursor()
    # Формируем SQL динамически
    fields = []
    params = []
    for key, value in lot_update.dict(exclude_unset=True).items():
        fields.append(f"{key} = %s")
        params.append(value)
    if not fields:
        raise HTTPException(status_code=400, detail="No fields to update")
    params.append(lot_id)
    cur.execute(f"UPDATE lot SET {', '.join(fields)} WHERE id = %s RETURNING *;", params)
    updated_lot = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return updated_lot

# ------------------- DELETE Лот -------------------
@app.delete("/lots/{lot_id}")
def delete_lot(lot_id: str):
    existing = get_lot_by_id(lot_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Lot not found")
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM lot WHERE id = %s RETURNING id;", (lot_id,))
    deleted = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return {"deleted_id": deleted["id"]}

@app.post("/bids")
def place_bid(bid: BidCreateModel):
    # Проверка существования лота
    lot = get_lot_by_id(bid.lot_id)
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")

    # Проверка минимальной ставки
    max_bid = get_max_bid_for_lot(bid.lot_id) or 0
    if bid.amount < max(lot["minimum_bet_amount"], max_bid):
        raise HTTPException(
            status_code=400,
            detail=f"Bid amount must be at least {max(lot['minimum_bet_amount'], max_bid)}"
        )

    conn = get_connection()
    cur = conn.cursor()
    new_id = str(uuid4())
    cur.execute("""
        INSERT INTO bid (id, lot_id, bidder_id, amount)
        VALUES (%s, %s, %s, %s)
        RETURNING id, lot_id, bidder_id, amount, state, created_at;
    """, (new_id, bid.lot_id, bid.bidder_id, bid.amount))
    new_bid = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return new_bid


@app.get("/analytics/top-sellers", response_model=list[TopSellerModel])
def api_top_sellers():
    return get_top_sellers()


@app.get("/analytics/lot-durations", response_model=list[LotDurationModel])
def api_lot_durations():
    return get_lot_durations()


@app.get("/analytics/payment-stats", response_model=list[PaymentStatsModel])
def api_payment_stats():
    return get_payment_stats()
