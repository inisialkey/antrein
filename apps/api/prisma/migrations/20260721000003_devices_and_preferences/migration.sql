-- 003_devices_and_preferences (docs/backend/database-design.md §9, §12)

CREATE TABLE devices (
    id text PRIMARY KEY,
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform text NOT NULL,
    app_version text NULL,
    device_name text NULL,
    push_provider text NULL,
    push_token text NULL,
    locale text NULL,
    timezone text NULL,
    status text NOT NULL DEFAULT 'active',
    last_seen_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE devices
ADD CONSTRAINT devices_platform_check
CHECK (platform IN ('android', 'ios'));

ALTER TABLE devices
ADD CONSTRAINT devices_status_check
CHECK (status IN ('active', 'inactive', 'invalid'));

CREATE INDEX devices_user_status_idx
ON devices(user_id, status);

CREATE UNIQUE INDEX devices_provider_token_uq
ON devices(push_provider, push_token)
WHERE push_token IS NOT NULL;

CREATE TABLE user_notification_preferences (
    user_id text PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    booking_updates boolean NOT NULL DEFAULT true,
    payment_updates boolean NOT NULL DEFAULT true,
    queue_updates boolean NOT NULL DEFAULT true,
    marketing boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
