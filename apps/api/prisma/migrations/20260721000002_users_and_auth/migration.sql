-- 002_users_and_auth (docs/backend/database-design.md §8, §10, §11)

CREATE TABLE users (
    id text PRIMARY KEY,
    email text NOT NULL,
    email_normalized text NOT NULL,
    phone_number text NULL,
    phone_number_normalized text NULL,
    password_hash text NOT NULL,
    name text NOT NULL,
    avatar_file_id text NULL,
    status text NOT NULL DEFAULT 'active',
    email_verified_at timestamptz NULL,
    phone_verified_at timestamptz NULL,
    last_login_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE users
ADD CONSTRAINT users_status_check
CHECK (status IN ('active', 'inactive', 'suspended', 'deleted'));

CREATE UNIQUE INDEX users_email_normalized_uq
ON users(email_normalized);

CREATE UNIQUE INDEX users_phone_normalized_uq
ON users(phone_number_normalized)
WHERE phone_number_normalized IS NOT NULL;

CREATE TABLE auth_sessions (
    id text PRIMARY KEY,
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id text NULL,
    refresh_token_hash text NOT NULL,
    token_family_id text NOT NULL,
    parent_session_id text NULL REFERENCES auth_sessions(id),
    status text NOT NULL DEFAULT 'active',
    issued_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    last_used_at timestamptz NULL,
    revoked_at timestamptz NULL,
    revoked_reason text NULL,
    ip_address inet NULL,
    user_agent text NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE auth_sessions
ADD CONSTRAINT auth_sessions_status_check
CHECK (status IN ('active', 'rotated', 'revoked', 'expired', 'compromised'));

ALTER TABLE auth_sessions
ADD CONSTRAINT auth_sessions_expiry_check
CHECK (expires_at > issued_at);

CREATE INDEX auth_sessions_user_status_idx
ON auth_sessions(user_id, status);

CREATE INDEX auth_sessions_family_idx
ON auth_sessions(token_family_id);

CREATE INDEX auth_sessions_expires_idx
ON auth_sessions(expires_at)
WHERE status = 'active';

CREATE TABLE password_reset_tokens (
    id text PRIMARY KEY,
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL,
    expires_at timestamptz NOT NULL,
    used_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX password_reset_tokens_hash_uq
ON password_reset_tokens(token_hash);

CREATE INDEX password_reset_tokens_expires_idx
ON password_reset_tokens(expires_at)
WHERE used_at IS NULL;
