-- Пользователи
INSERT INTO "user" (name, surname, email, phone_number, password, birthday_date)
VALUES
('Иван', 'Иванов', 'ivan@example.com', '+79111234567', 'pass123', '1990-01-01'),
('Мария', 'Петрова', 'maria@example.com', '+79119876543', 'pass123', '1992-05-12'),
('Алексей', 'Сидоров', 'alex@example.com', '+79115554433', 'pass123', '1985-07-20');

-- Лоты
INSERT INTO lot (name, description, state, seller_id, minimum_bet_amount, active_till)
VALUES
('Картина "Закат"', 'Красочная масляная картина на холсте.', 'ACTIVE',
 (SELECT id FROM "user" WHERE email='ivan@example.com'), 100, NOW() + INTERVAL '5 days'),
('Велосипед', 'Горный велосипед, почти новый.', 'ACTIVE',
 (SELECT id FROM "user" WHERE email='maria@example.com'), 500, NOW() + INTERVAL '7 days'),
('Ноутбук', 'Игровой ноутбук с видеокартой RTX 3060.', 'DRAFT',
 (SELECT id FROM "user" WHERE email='alex@example.com'), 1000, NOW() + INTERVAL '10 days');

-- Ставки
INSERT INTO bid (lot_id, bidder_id, state, amount)
VALUES
-- Ставки на картину
((SELECT id FROM lot WHERE name='Картина "Закат"'),
 (SELECT id FROM "user" WHERE email='maria@example.com'),
 'PLACED', 150),

((SELECT id FROM lot WHERE name='Картина "Закат"'),
 (SELECT id FROM "user" WHERE email='alex@example.com'),
 'PLACED', 200),

-- Ставки на велосипед
((SELECT id FROM lot WHERE name='Велосипед'),
 (SELECT id FROM "user" WHERE email='ivan@example.com'),
 'PLACED', 550);

INSERT INTO wallet (user_id, value, amount)
SELECT id, 1000, 1000
FROM "user"
WHERE id NOT IN (SELECT user_id FROM wallet);

-- Платежи за ставки
INSERT INTO payment (bid_id, wallet_id, status)
SELECT b.id, w.id, 'COMPLETED'
FROM bid b
JOIN wallet w ON w.user_id = b.bidder_id
WHERE NOT EXISTS (
    SELECT 1 FROM payment p WHERE p.bid_id = b.id
);

-- Доставка для платежей
INSERT INTO delivery (payment_id, status, sent_at)
SELECT p.id, 'SENT', NOW() + INTERVAL '2 days'
FROM payment p
WHERE NOT EXISTS (
    SELECT 1 FROM delivery d WHERE d.payment_id = p.id
);

-- Отзывы о продавцах
INSERT INTO seller_review (seller_id, author_id, content, rating)
SELECT l.seller_id, b.bidder_id, 
       'Отличный продавец, товар соответствует описанию.', 
       FLOOR(RANDOM() * 5 + 1)::INT
FROM bid b
JOIN lot l ON l.id = b.lot_id
WHERE NOT EXISTS (
    SELECT 1 FROM seller_review r 
    WHERE r.seller_id = l.seller_id AND r.author_id = b.bidder_id
);

-- ========================================
-- 1️⃣ Новые лоты (DRAFT и CANCELLED) - Битые автомобили
-- ========================================
INSERT INTO lot (name, description, state, seller_id, minimum_bet_amount, active_till)
SELECT * FROM (
    VALUES
    ('BMW X5 2015', 'Поврежден передний бампер и капот, мотор исправен.', 'DRAFT'::lot_state, 
        (SELECT id FROM "user" WHERE email='ivan@example.com'), 5000, NOW() + INTERVAL '5 days'),
    ('Toyota Corolla 2018', 'Серьезные повреждения кузова, требуется ремонт подвески.', 'CANCELLED'::lot_state, 
        (SELECT id FROM "user" WHERE email='maria@example.com'), 3000, NOW() + INTERVAL '3 days'),
    ('Ford Focus 2017', 'Мелкие вмятины, салон в хорошем состоянии.', 'ACTIVE'::lot_state, 
        (SELECT id FROM "user" WHERE email='alex@example.com'), 4000, NOW() + INTERVAL '7 days')
) AS t(name, description, state, seller_id, minimum_bet_amount, active_till)
WHERE NOT EXISTS (SELECT 1 FROM lot l WHERE l.name = t.name);

-- ========================================
-- 2️⃣ Ставки на новые и существующие лоты
-- ========================================
INSERT INTO bid (lot_id, bidder_id, state, amount)
SELECT * FROM (
    VALUES
    -- Ставки на BMW X5
    ((SELECT id FROM lot WHERE name='BMW X5 2015'), (SELECT id FROM "user" WHERE email='maria@example.com'), 'PLACED'::bid_state, 5500),
    ((SELECT id FROM lot WHERE name='BMW X5 2015'), (SELECT id FROM "user" WHERE email='alex@example.com'), 'PLACED'::bid_state, 6000),
    -- Ставки на Toyota Corolla
    ((SELECT id FROM lot WHERE name='Toyota Corolla 2018'), (SELECT id FROM "user" WHERE email='ivan@example.com'), 'PLACED'::bid_state, 3200),
    -- Ставки на Ford Focus
    ((SELECT id FROM lot WHERE name='Ford Focus 2017'), (SELECT id FROM "user" WHERE email='ivan@example.com'), 'PLACED'::bid_state, 4200),
    ((SELECT id FROM lot WHERE name='Ford Focus 2017'), (SELECT id FROM "user" WHERE email='maria@example.com'), 'PLACED'::bid_state, 4500)
) AS t(lot_id, bidder_id, state, amount)
WHERE NOT EXISTS (
    SELECT 1 FROM bid b
    WHERE b.lot_id = t.lot_id AND b.bidder_id = t.bidder_id AND b.amount = t.amount
);

-- ========================================
-- 3️⃣ Платежи за все ставки
-- ========================================
INSERT INTO payment (bid_id, wallet_id, status)
SELECT b.id, w.id, 
       CASE WHEN RANDOM() < 0.8 THEN 'COMPLETED'::payment_status ELSE 'FAILED'::payment_status END
FROM bid b
JOIN wallet w ON w.user_id = b.bidder_id
WHERE NOT EXISTS (SELECT 1 FROM payment p WHERE p.bid_id = b.id);

-- ========================================
-- 4️⃣ Доставка для всех платежей
-- ========================================
INSERT INTO delivery (payment_id, status, sent_at)
SELECT p.id,
       CASE WHEN RANDOM() < 0.7 THEN 'SENT'::delivery_status ELSE 'CREATED'::delivery_status END,
       NOW() + INTERVAL '2 days'
FROM payment p
WHERE NOT EXISTS (SELECT 1 FROM delivery d WHERE d.payment_id = p.id);

-- ========================================
-- 5️⃣ Отзывы продавцов
-- ========================================
INSERT INTO seller_review (seller_id, author_id, content, rating)
SELECT l.seller_id, b.bidder_id, 
       'Продавец честный, состояние авто соответствует описанию.',
       FLOOR(RANDOM() * 5 + 1)::INT
FROM bid b
JOIN lot l ON l.id = b.lot_id
WHERE NOT EXISTS (
    SELECT 1 FROM seller_review r
    WHERE r.seller_id = l.seller_id AND r.author_id = b.bidder_id
);

-- ========================================
-- 1️⃣ Топовые и редкие лоты (для фильтров и сортировки)
-- ========================================
INSERT INTO lot (name, description, state, seller_id, minimum_bet_amount, active_till, created_at)
SELECT * FROM (
    VALUES
    ('Mercedes GLE 2016', 'Сильно повреждена передняя часть, салон почти целый.', 'ACTIVE'::lot_state, 
        (SELECT id FROM "user" WHERE email='ivan@example.com'), 8000, NOW() + INTERVAL '10 days', NOW() - INTERVAL '1 day'),
    ('Honda Civic 2019', 'Кузов в хорошем состоянии, требуется косметика.', 'ACTIVE'::lot_state, 
        (SELECT id FROM "user" WHERE email='maria@example.com'), 7000, NOW() + INTERVAL '5 days', NOW() - INTERVAL '3 days'),
    ('Nissan X-Trail 2017', 'Средние повреждения, мотор и коробка исправны.', 'DRAFT'::lot_state, 
        (SELECT id FROM "user" WHERE email='alex@example.com'), 6000, NOW() + INTERVAL '15 days', NOW() - INTERVAL '2 days'),
    ('Kia Sportage 2015', 'Серьезные повреждения кузова, салон требует ремонта.', 'CANCELLED'::lot_state, 
        (SELECT id FROM "user" WHERE email='ivan@example.com'), 4000, NOW() + INTERVAL '1 days', NOW() - INTERVAL '5 days'),
    ('Volkswagen Tiguan 2018', 'Мелкие царапины, требует косметики.', 'ACTIVE'::lot_state, 
        (SELECT id FROM "user" WHERE email='maria@example.com'), 5000, NOW() + INTERVAL '7 days', NOW() - INTERVAL '4 days')
) AS t(name, description, state, seller_id, minimum_bet_amount, active_till, created_at)
WHERE NOT EXISTS (SELECT 1 FROM lot l WHERE l.name = t.name);

-- ========================================
-- 2️⃣ Ставки на новые лоты
-- ========================================
INSERT INTO bid (lot_id, bidder_id, state, amount)
SELECT * FROM (
    VALUES
    -- Mercedes GLE
    ((SELECT id FROM lot WHERE name='Mercedes GLE 2016'), (SELECT id FROM "user" WHERE email='maria@example.com'), 'PLACED'::bid_state, 8500),
    ((SELECT id FROM lot WHERE name='Mercedes GLE 2016'), (SELECT id FROM "user" WHERE email='alex@example.com'), 'PLACED'::bid_state, 9000),
    -- Honda Civic
    ((SELECT id FROM lot WHERE name='Honda Civic 2019'), (SELECT id FROM "user" WHERE email='ivan@example.com'), 'PLACED'::bid_state, 7500),
    -- Nissan X-Trail
    ((SELECT id FROM lot WHERE name='Nissan X-Trail 2017'), (SELECT id FROM "user" WHERE email='ivan@example.com'), 'PLACED'::bid_state, 6200),
    ((SELECT id FROM lot WHERE name='Nissan X-Trail 2017'), (SELECT id FROM "user" WHERE email='maria@example.com'), 'PLACED'::bid_state, 6300),
    -- Kia Sportage
    ((SELECT id FROM lot WHERE name='Kia Sportage 2015'), (SELECT id FROM "user" WHERE email='alex@example.com'), 'PLACED'::bid_state, 4500),
    -- Volkswagen Tiguan
    ((SELECT id FROM lot WHERE name='Volkswagen Tiguan 2018'), (SELECT id FROM "user" WHERE email='ivan@example.com'), 'PLACED'::bid_state, 5200),
    ((SELECT id FROM lot WHERE name='Volkswagen Tiguan 2018'), (SELECT id FROM "user" WHERE email='alex@example.com'), 'PLACED'::bid_state, 5500)
) AS t(lot_id, bidder_id, state, amount)
WHERE NOT EXISTS (
    SELECT 1 FROM bid b
    WHERE b.lot_id = t.lot_id AND b.bidder_id = t.bidder_id AND b.amount = t.amount
);

-- ========================================
-- 3️⃣ Платежи за новые ставки
-- ========================================
INSERT INTO payment (bid_id, wallet_id, status)
SELECT b.id, w.id, 
       CASE WHEN RANDOM() < 0.8 THEN 'COMPLETED'::payment_status ELSE 'FAILED'::payment_status END
FROM bid b
JOIN wallet w ON w.user_id = b.bidder_id
WHERE NOT EXISTS (SELECT 1 FROM payment p WHERE p.bid_id = b.id);

-- ========================================
-- 4️⃣ Доставка для всех новых платежей
-- ========================================
INSERT INTO delivery (payment_id, status, sent_at)
SELECT p.id,
       CASE WHEN RANDOM() < 0.7 THEN 'SENT'::delivery_status ELSE 'CREATED'::delivery_status END,
       NOW() + INTERVAL '2 days'
FROM payment p
WHERE NOT EXISTS (SELECT 1 FROM delivery d WHERE d.payment_id = p.id);

-- ========================================
-- 5️⃣ Отзывы продавцов для новых лотов
-- ========================================
INSERT INTO seller_review (seller_id, author_id, content, rating)
SELECT l.seller_id, b.bidder_id, 
       'Продавец честный, автомобиль соответствует описанию.',
       FLOOR(RANDOM() * 5 + 1)::INT
FROM bid b
JOIN lot l ON l.id = b.lot_id
WHERE NOT EXISTS (
    SELECT 1 FROM seller_review r
    WHERE r.seller_id = l.seller_id AND r.author_id = b.bidder_id
);
