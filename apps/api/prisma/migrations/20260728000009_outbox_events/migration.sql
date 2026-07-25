-- 009_outbox_events (docs/backend/database-design.md §49–§50)
-- Transactional outbox: business state + an outbox row commit in one transaction;
-- the in-process dispatcher claims rows with FOR UPDATE SKIP LOCKED and publishes
-- realtime events. Delivery failure never rolls back business state (arch §33).

CREATE TABLE outbox_events (
    id text PRIMARY KEY,
    event_type text NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id text NOT NULL,
    payload jsonb NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    attempt_count integer NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    claimed_at timestamptz NULL,
    claimed_by text NULL,
    processed_at timestamptz NULL,
    last_error text NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE outbox_events
ADD CONSTRAINT outbox_events_attempt_check
CHECK (attempt_count >= 0);

ALTER TABLE outbox_events
ADD CONSTRAINT outbox_events_status_check
CHECK (status IN ('pending', 'processing', 'processed', 'failed', 'dead_letter'));

-- Worker claim scan: due pending/failed rows in created order (partial — the
-- terminal processed/dead_letter rows are never scanned).
CREATE INDEX outbox_events_due_idx
ON outbox_events(status, next_attempt_at, created_at)
WHERE status IN ('pending', 'failed');

CREATE INDEX outbox_events_aggregate_idx
ON outbox_events(aggregate_type, aggregate_id, created_at);
