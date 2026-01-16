from pydantic import BaseModel, EmailStr, Field, PositiveFloat, constr
from typing import Optional
from datetime import datetime
# ===== Пользователь =====
class UserModel(BaseModel):
    id: str
    name: str
    surname: str
    email: EmailStr
    phone_number: Optional[str]
    birthday_date: Optional[datetime]
    created_at: datetime

# ===== Лот (для вложенных данных в ставках) =====
class LotInBidModel(BaseModel):
    id: str
    name: str
    state: str
    minimum_bet_amount: float

# ===== Ставка пользователя =====
class BidModel(BaseModel):
    bid_id: str
    amount: float
    state: str
    bid_created_at: datetime
    lot: LotInBidModel

    class Config:
        # orm_mode = True  <-- старый вариант для Pydantic v1
        from_attributes = True  # Pydantic v2

class TopSellerModel(BaseModel):
    seller_id: str
    seller_name: str
    seller_surname: str
    total_earned: float

    class Config:
        from_attributes = True

class LotDurationModel(BaseModel):
    lot_id: str
    lot_name: str
    duration_days: float

    class Config:
        from_attributes = True

class PaymentStatsModel(BaseModel):
    status: str
    count: int
    percentage: float

    class Config:
        from_attributes = True

# ------------------- Лот -------------------
class LotCreateModel(BaseModel):
    name: constr(min_length=1)
    description: constr(min_length=1)
    minimum_bet_amount: PositiveFloat
    active_till: Optional[datetime] = None

class LotUpdateModel(BaseModel):
    name: Optional[constr(min_length=1)]
    description: Optional[constr(min_length=1)]
    minimum_bet_amount: Optional[PositiveFloat]
    active_till: Optional[datetime]
    state: Optional[str]

# ------------------- Ставка -------------------
class BidCreateModel(BaseModel):
    lot_id: str
    bidder_id: str
    amount: PositiveFloat