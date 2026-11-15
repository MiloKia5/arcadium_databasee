-- Arcadium: PostgreSQL schema
-- Run this file in pgAdmin 4 (Query Tool) against an empty database.
-- PostgreSQL 14+

BEGIN;

CREATE TABLE users (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    telegram_id     BIGINT NOT NULL UNIQUE,
    full_name       VARCHAR(200) NOT NULL,
    university      VARCHAR(200) NOT NULL,
    course          SMALLINT NOT NULL CHECK (course BETWEEN 1 AND 12),
    study_group     VARCHAR(80) NOT NULL,
    balance         BIGINT NOT NULL DEFAULT 0 CHECK (balance >= 0),
    character_id    SMALLINT CHECK (character_id BETWEEN 1 AND 4),
    role            VARCHAR(20) NOT NULL DEFAULT 'user'
                    CHECK (role IN ('user', 'organizer', 'admin')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    registered_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    price           BIGINT NOT NULL CHECK (price >= 0),
    quantity        INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    image_url       TEXT,
    is_featured     BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Topics and subtopics make organizer rewards configurable and prevent
-- awarding the same action to the same user more than once.
CREATE TABLE award_topics (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(160) NOT NULL UNIQUE,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE award_actions (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    topic_id        BIGINT NOT NULL REFERENCES award_topics(id) ON DELETE RESTRICT,
    name            VARCHAR(160) NOT NULL,
    description     TEXT,
    reward_amount   BIGINT NOT NULL CHECK (reward_amount > 0),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (topic_id, name),
    UNIQUE (id, topic_id)
);

CREATE TABLE achievements (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(200) NOT NULL UNIQUE,
    description     TEXT,
    reward_amount   BIGINT NOT NULL DEFAULT 0 CHECK (reward_amount >= 0),
    achievement_type VARCHAR(20) NOT NULL
                    CHECK (achievement_type IN ('automatic', 'admin')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE banners (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    image_url       TEXT NOT NULL,
    target_url      TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'scheduled', 'published', 'archived')),
    display_order   INTEGER NOT NULL DEFAULT 0,
    starts_at       TIMESTAMPTZ,
    ends_at         TIMESTAMPTZ,
    created_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE transactions (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation_id    UUID NOT NULL UNIQUE,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    actor_id        BIGINT REFERENCES users(id) ON DELETE SET NULL,
    transaction_type VARCHAR(20) NOT NULL
                    CHECK (transaction_type IN ('credit', 'debit', 'adjustment', 'purchase', 'achievement')),
    amount          BIGINT NOT NULL CHECK (amount > 0),
    balance_after   BIGINT NOT NULL CHECK (balance_after >= 0),
    reason          TEXT NOT NULL,
    product_id      BIGINT REFERENCES products(id) ON DELETE RESTRICT,
    award_action_id BIGINT REFERENCES award_actions(id) ON DELETE RESTRICT,
    achievement_id  BIGINT REFERENCES achievements(id) ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (
        (transaction_type = 'purchase' AND product_id IS NOT NULL)
        OR (transaction_type <> 'purchase' AND product_id IS NULL)
    ),
    CHECK (
        (transaction_type = 'achievement' AND achievement_id IS NOT NULL)
        OR (transaction_type <> 'achievement' AND achievement_id IS NULL)
    ),
    CHECK (
        (transaction_type = 'credit' AND award_action_id IS NOT NULL)
        OR (transaction_type <> 'credit' AND award_action_id IS NULL)
    )
);

-- One achievement can be granted to a user only once.
CREATE TABLE user_achievements (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    achievement_id      BIGINT NOT NULL REFERENCES achievements(id) ON DELETE RESTRICT,
    granted_by          BIGINT REFERENCES users(id) ON DELETE SET NULL,
    transaction_id      BIGINT UNIQUE REFERENCES transactions(id) ON DELETE SET NULL,
    earned_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, achievement_id)
);

-- Explicit indexes for common bot and mini-app queries.
CREATE INDEX idx_users_balance_desc ON users (balance DESC) WHERE is_active = TRUE;
CREATE INDEX idx_users_role ON users (role);
CREATE INDEX idx_transactions_user_created ON transactions (user_id, created_at DESC);
CREATE INDEX idx_transactions_actor_created ON transactions (actor_id, created_at DESC);
CREATE INDEX idx_transactions_type ON transactions (transaction_type);
CREATE INDEX idx_banners_active_schedule ON banners (status, starts_at, ends_at);
CREATE INDEX idx_products_store ON products (is_active, is_featured);
CREATE INDEX idx_user_achievements_user ON user_achievements (user_id, earned_at DESC);

COMMENT ON TABLE users IS 'Единый профиль пользователя Telegram-бота и Mini App; баланс хранится в аркоинах.';
COMMENT ON TABLE products IS 'Товары ярмарки; покупка выполняется организатором, а не пользователем в Mini App.';
COMMENT ON TABLE transactions IS 'Неизменяемый журнал операций с аркоинами.';
COMMENT ON TABLE award_topics IS 'Темы начисления аркоинов организаторами.';
COMMENT ON TABLE award_actions IS 'Подтемы/действия начисления с фиксированной наградой.';
COMMENT ON TABLE user_achievements IS 'Связь пользователей и полученных ими достижений.';
COMMENT ON TABLE banners IS 'Объявления главного экрана Mini App.';

COMMIT;
