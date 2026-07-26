-- 010_notifications (docs/backend/database-design.md §42, §43)

CREATE TABLE notifications (
    id text PRIMARY KEY,
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    resource_type text NULL,
    resource_id text NULL,
    is_read boolean NOT NULL DEFAULT false,
    read_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_user_created_idx
ON notifications(user_id, created_at DESC);

CREATE INDEX notifications_user_unread_idx
ON notifications(user_id, created_at DESC)
WHERE is_read = false;

CREATE TABLE notification_deliveries (
    id text PRIMARY KEY,
    notification_id text NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    device_id text NULL REFERENCES devices(id) ON DELETE SET NULL,
    provider text NOT NULL,
    provider_message_id text NULL,
    status text NOT NULL,
    attempt_count integer NOT NULL DEFAULT 0,
    last_error_code text NULL,
    sent_at timestamptz NULL,
    delivered_at timestamptz NULL,
    failed_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE notification_deliveries
ADD CONSTRAINT notification_deliveries_status_check
CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'invalid_device'));

CREATE INDEX notification_deliveries_status_idx
ON notification_deliveries(status, created_at);

CREATE INDEX notification_deliveries_notification_idx
ON notification_deliveries(notification_id);
