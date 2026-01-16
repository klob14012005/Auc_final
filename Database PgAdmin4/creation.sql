CREATE TABLE "user" (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(100) NOT NULL,
    surname         VARCHAR(100) NOT NULL,
    email           VARCHAR(255) NOT NULL UNIQUE,
    phone_number    VARCHAR(20) UNIQUE,
    password        TEXT NOT NULL,
    birthday_date   DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE EXTENSION IF NOT EXISTS pgcrypto;


CREATE TABLE wallet (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL UNIQUE,
    value       NUMERIC(12,2) NOT NULL DEFAULT 0,
    amount      NUMERIC(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT fk_wallet_user
        FOREIGN KEY (user_id) REFERENCES "user"(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_wallet_non_negative
        CHECK (value >= 0 AND amount >= 0)
);


CREATE TABLE lot (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    state               lot_state NOT NULL DEFAULT 'DRAFT',
    seller_id           UUID NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ,
    active_till         TIMESTAMPTZ,
    minimum_bet_amount  NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_lot_seller
        FOREIGN KEY (seller_id) REFERENCES "user"(id),

    CONSTRAINT chk_lot_min_bet
        CHECK (minimum_bet_amount > 0),

    CONSTRAINT chk_lot_dates
        CHECK (active_till IS NULL OR active_till > created_at)
);

CREATE TABLE bid (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lot_id      UUID NOT NULL,
    bidder_id  UUID NOT NULL,
    state       bid_state NOT NULL DEFAULT 'PLACED',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    amount      NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_bid_lot
        FOREIGN KEY (lot_id) REFERENCES lot(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_bid_user
        FOREIGN KEY (bidder_id) REFERENCES "user"(id),

    CONSTRAINT chk_bid_amount
        CHECK (amount > 0)
);

CREATE TABLE payment (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bid_id      UUID NOT NULL UNIQUE,
    wallet_id   UUID NOT NULL,
    status      payment_status NOT NULL DEFAULT 'CREATED',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_payment_bid
        FOREIGN KEY (bid_id) REFERENCES bid(id),

    CONSTRAINT fk_payment_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallet(id)
);

CREATE TABLE delivery (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id  UUID NOT NULL UNIQUE,
    status      delivery_status NOT NULL DEFAULT 'CREATED',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at     TIMESTAMPTZ,

    CONSTRAINT fk_delivery_payment
        FOREIGN KEY (payment_id) REFERENCES payment(id)
);

CREATE TABLE seller_review (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id   UUID NOT NULL,
    author_id   UUID NOT NULL,
    content     TEXT,
    rating      INTEGER NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_review_seller
        FOREIGN KEY (seller_id) REFERENCES "user"(id),

    CONSTRAINT fk_review_author
        FOREIGN KEY (author_id) REFERENCES "user"(id),

    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5)
);

CREATE INDEX idx_lot_state ON lot(state);
CREATE INDEX idx_lot_active_till ON lot(active_till);

CREATE INDEX idx_bid_lot_id ON bid(lot_id);
CREATE INDEX idx_bid_bidder_id ON bid(bidder_id);

CREATE INDEX idx_payment_wallet_id ON payment(wallet_id);
CREATE INDEX idx_review_seller_id ON seller_review(seller_id);
