from db.connection import get_connection

# ===== Лоты =====
def get_all_lots():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, name, description, state, minimum_bet_amount,
               seller_id, created_at, active_till
        FROM lot
        ORDER BY created_at DESC;
    """)
    lots = cur.fetchall()
    cur.close()
    conn.close()
    return lots


def get_lots_with_sellers(
        state: str | list[str] | None = None,
        seller_id: str | None = None,
        min_amount: float | None = None,
        max_amount: float | None = None,
        created_from: str | None = None,  # YYYY-MM-DD
        created_to: str | None = None,  # YYYY-MM-DD
        max_bid: float | None = None,
        search: str | None = None,
        order_by: str = "created_at",
        order_dir: str = "DESC"
):
    sql = """
        SELECT l.id, l.name, l.description, l.state, l.minimum_bet_amount,
               l.created_at, l.active_till,
               u.name AS seller_name, u.surname AS seller_surname, u.email AS seller_email,
               COALESCE(MAX(b.amount), 0) AS max_bid
        FROM lot l
        JOIN "user" u ON l.seller_id = u.id
        LEFT JOIN bid b ON b.lot_id = l.id
    """
    conditions = []
    params = []

    # ===== Фильтры =====
    if state:
        if isinstance(state, str):
            conditions.append("l.state = %s")
            params.append(state)
        else:
            placeholders = ", ".join(["%s"] * len(state))
            conditions.append(f"l.state IN ({placeholders})")
            params.extend(state)

    if seller_id:
        conditions.append("l.seller_id = %s")
        params.append(seller_id)

    if min_amount is not None:
        conditions.append("l.minimum_bet_amount >= %s")
        params.append(min_amount)

    if max_amount is not None:
        conditions.append("l.minimum_bet_amount <= %s")
        params.append(max_amount)

    if created_from:
        conditions.append("l.created_at >= %s")
        params.append(created_from)

    if created_to:
        conditions.append("l.created_at <= %s")
        params.append(created_to)

    if search:
        conditions.append("(l.name ILIKE %s OR l.description ILIKE %s)")
        params.append(f"%{search}%")
        params.append(f"%{search}%")

    if max_bid is not None:
        conditions.append("COALESCE(MAX(b.amount), 0) <= %s")
        params.append(max_bid)

    # ===== WHERE =====
    if conditions:
        sql += " WHERE " + " AND ".join(conditions)

    sql += " GROUP BY l.id, u.id"  # для MAX(b.amount)

    allowed_order_by = ["created_at", "minimum_bet_amount", "name", "state", "max_bid"]
    if order_by not in allowed_order_by:
        order_by = "created_at"

    order_dir = order_dir.upper()
    if order_dir not in ["ASC", "DESC"]:
        order_dir = "DESC"

    sql += f" ORDER BY {order_by} {order_dir};"

    conn = get_connection()
    cur = conn.cursor()
    cur.execute(sql, params)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows

# ===== Аналитика =====

def get_top_sellers():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            u.id AS seller_id,
            u.name AS seller_name,
            u.surname AS seller_surname,
            SUM(b.amount) AS total_earned
        FROM lot l
        JOIN bid b ON b.lot_id = l.id
        JOIN "user" u ON u.id = l.seller_id
        WHERE l.state = 'CLOSED'
        GROUP BY u.id, u.name, u.surname
        ORDER BY total_earned DESC;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


def get_lot_durations():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            id AS lot_id,
            name AS lot_name,
            EXTRACT(EPOCH FROM (active_till - created_at)) / 86400 AS duration_days
        FROM lot
        WHERE active_till IS NOT NULL;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


def get_payment_stats():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT
            status,
            COUNT(*) AS count
        FROM payment
        GROUP BY status;
    """)
    rows = cur.fetchall()

    total = sum(row["count"] for row in rows)

    result = []
    for row in rows:
        result.append({
            "status": row["status"],
            "count": row["count"],
            "percentage": round((row["count"] / total) * 100, 2) if total else 0
        })

    cur.close()
    conn.close()
    return result


def get_lot_by_id(lot_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, name, description, state, minimum_bet_amount,
               seller_id, created_at, active_till
        FROM lot
        WHERE id = %s;
    """, (lot_id,))
    lot = cur.fetchone()
    cur.close()
    conn.close()
    return lot

# ===== Ставки =====
def get_bids_by_lot(lot_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, lot_id, bidder_id, state, created_at, amount
        FROM bid
        WHERE lot_id = %s
        ORDER BY created_at ASC;
    """, (lot_id,))
    bids = cur.fetchall()
    cur.close()
    conn.close()
    return bids

def get_max_bid_for_lot(lot_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT MAX(amount) AS max_bid
        FROM bid
        WHERE lot_id = %s;
    """, (lot_id,))
    result = cur.fetchone()
    cur.close()
    conn.close()
    return result['max_bid'] if result else None

# ===== Пользователи =====
def get_user_by_id(user_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, name, surname, email, phone_number, birthday_date, created_at
        FROM "user"
        WHERE id = %s;
    """, (user_id,))
    user = cur.fetchone()
    cur.close()
    conn.close()
    return user

# ===== Пользователи =====
def get_all_users():
    """
    Возвращает список всех пользователей.
    """
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, name, surname, email, phone_number, birthday_date, created_at
        FROM "user"
        ORDER BY created_at DESC;
    """)
    users = cur.fetchall()
    cur.close()
    conn.close()
    return users

def get_user_bids(user_id):
    """
    Возвращает все ставки пользователя с данными о лоте в формате dict.
    """
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT b.id AS bid_id, b.amount, b.state, b.created_at AS bid_created_at,
               l.id AS lot_id, l.name AS lot_name, l.state AS lot_state, l.minimum_bet_amount
        FROM bid b
        JOIN lot l ON b.lot_id = l.id
        WHERE b.bidder_id = %s
        ORDER BY b.created_at DESC;
    """, (user_id,))
    rows = cur.fetchall()
    cur.close()
    conn.close()

    # Преобразуем в структуру Pydantic: вложенный lot
    bids = []
    for r in rows:
        bids.append({
            "bid_id": r["bid_id"],
            "amount": float(r["amount"]),
            "state": r["state"],
            "bid_created_at": r["bid_created_at"],
            "lot": {
                "id": r["lot_id"],
                "name": r["lot_name"],
                "state": r["lot_state"],
                "minimum_bet_amount": float(r["minimum_bet_amount"])
            }
        })
    return bids