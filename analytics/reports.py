import pandas as pd
from db.models import get_all_lots, get_bids_by_lot
from db.connection import get_connection
from typing import List
from datetime import datetime
from db.schemas import TopSellerModel, LotDurationModel, PaymentStatsModel
def average_lot_price():
    lots = get_all_lots()
    total = 0
    count = 0
    for lot in lots:
        bids = get_bids_by_lot(lot['id'])
        if bids:
            max_bid = max(bid['amount'] for bid in bids)
            total += max_bid
            count += 1
    return total / count if count > 0 else 0

def top_active_lots(n=5):
    lots = get_all_lots()
    active_lots = [lot for lot in lots if lot['state'] == 'ACTIVE']
    active_lots.sort(key=lambda x: x['created_at'], reverse=True)
    return active_lots[:n]


# ----------------------
# 1️⃣ Топ продавцов по сумме проданных лотов
# ----------------------
def top_sellers(limit: int = 5) -> List[TopSellerModel]:
    sql = """
        SELECT u.id AS seller_id, u.name AS seller_name, u.surname AS seller_surname,
               SUM(b.amount) AS total_earned
        FROM lot l
        JOIN "user" u ON l.seller_id = u.id
        JOIN bid b ON b.lot_id = l.id
        WHERE b.state = 'WON'  -- только выигранные ставки
        GROUP BY u.id
        ORDER BY total_earned DESC
        LIMIT %s;
    """
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(sql, (limit,))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [TopSellerModel(**row) for row in rows]

# ----------------------
# 2️⃣ Среднее время жизни лота (в днях)
# ----------------------
def average_lot_duration() -> float:
    sql = """
        SELECT EXTRACT(EPOCH FROM (active_till - created_at))/86400 AS duration_days
        FROM lot
        WHERE active_till IS NOT NULL;
    """
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(sql)
    durations = [row['duration_days'] for row in cur.fetchall()]
    cur.close()
    conn.close()
    return sum(durations)/len(durations) if durations else 0

# ----------------------
# 3️⃣ Статистика по платежам
# ----------------------
def payment_stats() -> List[PaymentStatsModel]:
    sql_total = "SELECT COUNT(*) AS total FROM payment;"
    sql_group = "SELECT status, COUNT(*) AS count FROM payment GROUP BY status;"

    conn = get_connection()
    cur = conn.cursor()
    cur.execute(sql_total)
    total = cur.fetchone()['total']

    cur.execute(sql_group)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    stats = []
    for row in rows:
        percentage = (row['count'] / total * 100) if total > 0 else 0
        stats.append(PaymentStatsModel(status=row['status'], count=row['count'], percentage=percentage))
    return stats