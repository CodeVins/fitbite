CREATE TABLE users (
    id            UUID PRIMARY KEY,
    email         VARCHAR(254) NOT NULL UNIQUE CHECK (email = lower(email)),
    password_hash VARCHAR(100) NOT NULL,
    nickname      VARCHAR(50)  NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE consents (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id   UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type      VARCHAR(30)  NOT NULL,
    version   VARCHAR(30)  NOT NULL,
    agreed_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX consents_user_id_idx ON consents (user_id);

CREATE TABLE refresh_tokens (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash VARCHAR(64)  NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ  NOT NULL,
    revoked_at TIMESTAMPTZ
);
CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);
