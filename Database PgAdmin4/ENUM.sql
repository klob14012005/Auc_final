-- Состояния лота
CREATE TYPE lot_state AS ENUM (
    'DRAFT',
    'ACTIVE',
    'CLOSED',
    'CANCELLED'
);

-- Состояния ставки
CREATE TYPE bid_state AS ENUM (
    'PLACED',
    'WON',
    'LOST'
);

-- Статусы платежа
CREATE TYPE payment_status AS ENUM (
    'CREATED',
    'COMPLETED',
    'FAILED'
);

-- Статусы доставки
CREATE TYPE delivery_status AS ENUM (
    'CREATED',
    'SENT',
    'DELIVERED'
);
