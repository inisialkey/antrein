-- 008_queue (database-design §37–§41, realtime-queue §14/§22/§27, ADRs 0038/0041)
-- M8 scope: check-in + queue REST slice. Outbox / realtime / push deferred to M9.

-- ---------------------------------------------------------------------------
-- walk-in customer identity on bookings (database-design §26/§32, realtime-queue
-- §32). Nullable — only walk-ins carry an operational name/phone; scheduled
-- bookings resolve the customer through customer_user_id.
-- ---------------------------------------------------------------------------
ALTER TABLE bookings ADD COLUMN walk_in_customer_name text NULL;
ALTER TABLE bookings ADD COLUMN walk_in_phone_number text NULL;

-- ---------------------------------------------------------------------------
-- queue_counters (database-design §37) — atomic per-(outlet, business_date)
-- number generation + aggregate queue version (ADR 0041).
-- ---------------------------------------------------------------------------
CREATE TABLE queue_counters (
    outlet_id text NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
    business_date date NOT NULL,
    last_number integer NOT NULL DEFAULT 0,
    version integer NOT NULL DEFAULT 1,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (outlet_id, business_date)
);

ALTER TABLE queue_counters
ADD CONSTRAINT queue_counters_number_check
CHECK (last_number >= 0);

-- ---------------------------------------------------------------------------
-- queue_entries (database-design §38). sort_order integer per ADR 0038.
-- ---------------------------------------------------------------------------
CREATE TABLE queue_entries (
    id text PRIMARY KEY,
    booking_id text NOT NULL REFERENCES bookings(id),
    business_id text NOT NULL REFERENCES businesses(id),
    outlet_id text NOT NULL REFERENCES outlets(id),
    staff_id text NULL REFERENCES staff_profiles(id),
    business_date date NOT NULL,
    queue_number integer NOT NULL,
    display_number text NOT NULL,
    status text NOT NULL,
    sort_order integer NOT NULL,
    checked_in_at timestamptz NOT NULL,
    called_at timestamptz NULL,
    last_recalled_at timestamptz NULL,
    recall_count integer NOT NULL DEFAULT 0,
    service_started_at timestamptz NULL,
    completed_at timestamptz NULL,
    no_show_at timestamptz NULL,
    cancelled_at timestamptz NULL,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE queue_entries
ADD CONSTRAINT queue_entries_status_check
CHECK (status IN (
    'waiting',
    'called',
    'skipped',
    'in_service',
    'completed',
    'cancelled',
    'no_show'
));

ALTER TABLE queue_entries
ADD CONSTRAINT queue_entries_number_check
CHECK (queue_number > 0);

ALTER TABLE queue_entries
ADD CONSTRAINT queue_entries_recall_check
CHECK (recall_count >= 0);

-- One queue entry per booking; unique number per outlet + business date.
CREATE UNIQUE INDEX queue_entries_booking_uq
ON queue_entries(booking_id);

CREATE UNIQUE INDEX queue_entries_outlet_date_number_uq
ON queue_entries(outlet_id, business_date, queue_number);

-- ADR 0041: at most one called entry per outlet+date, one in-service per staff.
CREATE UNIQUE INDEX queue_entries_one_called_uq
ON queue_entries(outlet_id, business_date)
WHERE status = 'called';

CREATE UNIQUE INDEX queue_entries_one_in_service_per_staff_uq
ON queue_entries(staff_id)
WHERE status = 'in_service' AND staff_id IS NOT NULL;

CREATE INDEX queue_entries_outlet_date_status_idx
ON queue_entries(outlet_id, business_date, status, sort_order, checked_in_at);

CREATE INDEX queue_entries_staff_status_idx
ON queue_entries(staff_id, status)
WHERE staff_id IS NOT NULL;

CREATE INDEX queue_entries_updated_idx
ON queue_entries(updated_at);

-- ---------------------------------------------------------------------------
-- queue_status_history (database-design §40) — append-only.
-- ---------------------------------------------------------------------------
CREATE TABLE queue_status_history (
    id text PRIMARY KEY,
    queue_entry_id text NOT NULL REFERENCES queue_entries(id) ON DELETE CASCADE,
    from_status text NULL,
    to_status text NOT NULL,
    actor_user_id text NULL REFERENCES users(id),
    actor_type text NOT NULL,
    reason text NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    request_id text NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX queue_status_history_entry_created_idx
ON queue_status_history(queue_entry_id, created_at);

-- ---------------------------------------------------------------------------
-- queue_reorders (database-design §41) — reorder audit.
-- ---------------------------------------------------------------------------
CREATE TABLE queue_reorders (
    id text PRIMARY KEY,
    business_id text NOT NULL REFERENCES businesses(id),
    outlet_id text NOT NULL REFERENCES outlets(id),
    business_date date NOT NULL,
    actor_user_id text NOT NULL REFERENCES users(id),
    previous_order jsonb NOT NULL,
    new_order jsonb NOT NULL,
    reason text NOT NULL,
    request_id text NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX queue_reorders_outlet_date_idx
ON queue_reorders(outlet_id, business_date, created_at);
