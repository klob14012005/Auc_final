ALTER TABLE lot
ADD CONSTRAINT chk_lot_name_not_empty
CHECK (trim(name) <> '');

ALTER TABLE lot
ADD CONSTRAINT chk_lot_description_not_empty
CHECK (description IS NOT NULL AND trim(description) <> '');

CREATE OR REPLACE FUNCTION check_bid_amount()
RETURNS TRIGGER AS $$
DECLARE
    min_amount NUMERIC;
BEGIN
    SELECT minimum_bet_amount
    INTO min_amount
    FROM lot
    WHERE id = NEW.lot_id;

    IF NEW.amount < min_amount THEN
        RAISE EXCEPTION
        'Bid amount (%) is less than minimum bet amount (%)',
        NEW.amount, min_amount;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_bid_amount
BEFORE INSERT OR UPDATE ON bid
FOR EACH ROW
EXECUTE FUNCTION check_bid_amount();

ALTER TABLE "user"
ADD CONSTRAINT chk_user_name_not_empty
CHECK (trim(name) <> '');

ALTER TABLE "user"
ADD CONSTRAINT chk_user_surname_not_empty
CHECK (trim(surname) <> '');

ALTER TABLE "user"
ADD CONSTRAINT chk_user_password_not_empty
CHECK (trim(password) <> '');

ALTER TABLE "user"
ADD CONSTRAINT chk_user_email_format
CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE "user"
ADD CONSTRAINT chk_user_phone_format
CHECK (
    phone_number IS NULL
    OR phone_number ~ '^\+?[0-9]{10,15}$'
);

ALTER TABLE "user"
ADD CONSTRAINT chk_user_age
CHECK (
    birthday_date IS NULL
    OR birthday_date <= CURRENT_DATE - INTERVAL '18 years'
);

ALTER TABLE delivery
ADD CONSTRAINT chk_delivery_dates
CHECK (sent_at IS NULL OR sent_at >= created_at);

ALTER TABLE seller_review
ADD CONSTRAINT chk_review_content_not_empty
CHECK (trim(content) <> '');

ALTER TABLE lot
ADD CONSTRAINT chk_lot_description_not_empty
CHECK (description IS NOT NULL AND trim(description) <> '');

