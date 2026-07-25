-- 006_bookings_and_payments (database-design §26–§32, ADRs 0027/0038/0040)
-- M6 scope: bookings, snapshots, status history, reservations (overlap
-- protection), booking code counters, payments (pay-at-location slice).
-- payment_events / refunds land with the provider milestone (M7).

-- ---------------------------------------------------------------------------
-- bookings (database-design §26)
-- ---------------------------------------------------------------------------
CREATE TABLE bookings (
    id text PRIMARY KEY,
    booking_code text NOT NULL,
    customer_user_id text NULL REFERENCES users(id),
    business_id text NOT NULL REFERENCES businesses(id),
    outlet_id text NOT NULL REFERENCES outlets(id),
    service_id text NOT NULL REFERENCES services(id),
    staff_id text NULL REFERENCES staff_profiles(id),
    booking_type text NOT NULL,
    status text NOT NULL,
    scheduled_at timestamptz NULL,
    expected_ends_at timestamptz NULL,
    checked_in_at timestamptz NULL,
    customer_notes text NULL,
    internal_notes text NULL,
    payment_option text NOT NULL,
    business_date date NOT NULL,
    version integer NOT NULL DEFAULT 1,
    cancelled_at timestamptz NULL,
    completed_at timestamptz NULL,
    no_show_at timestamptz NULL,
    created_by_user_id text NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bookings
ADD CONSTRAINT bookings_type_check
CHECK (booking_type IN ('scheduled', 'walk_in'));

ALTER TABLE bookings
ADD CONSTRAINT bookings_status_check
CHECK (status IN (
    'draft',
    'pending_payment',
    'confirmed',
    'checked_in',
    'waiting',
    'called',
    'in_service',
    'completed',
    'cancelled',
    'expired',
    'no_show'
));

ALTER TABLE bookings
ADD CONSTRAINT bookings_payment_option_check
CHECK (payment_option IN ('pay_at_location', 'full_payment', 'deposit'));

ALTER TABLE bookings
ADD CONSTRAINT bookings_schedule_check
CHECK (
    (booking_type = 'walk_in')
    OR
    (booking_type = 'scheduled' AND scheduled_at IS NOT NULL AND expected_ends_at IS NOT NULL)
);

ALTER TABLE bookings
ADD CONSTRAINT bookings_time_order_check
CHECK (
    scheduled_at IS NULL
    OR expected_ends_at IS NULL
    OR scheduled_at < expected_ends_at
);

-- Per-business: codes share the ANT- prefix across businesses (ADR 0038),
-- so the same code appearing under two businesses is expected.
CREATE UNIQUE INDEX bookings_code_uq ON bookings(business_id, booking_code);

CREATE INDEX bookings_customer_created_idx
ON bookings(customer_user_id, created_at DESC);

CREATE INDEX bookings_business_date_idx
ON bookings(business_id, business_date, status);

CREATE INDEX bookings_outlet_date_idx
ON bookings(outlet_id, business_date, status);

CREATE INDEX bookings_staff_schedule_idx
ON bookings(staff_id, scheduled_at, expected_ends_at)
WHERE staff_id IS NOT NULL;

CREATE INDEX bookings_status_scheduled_idx
ON bookings(status, scheduled_at);

-- ---------------------------------------------------------------------------
-- booking_snapshots (database-design §29)
-- ---------------------------------------------------------------------------
CREATE TABLE booking_snapshots (
    booking_id text PRIMARY KEY REFERENCES bookings(id) ON DELETE CASCADE,
    business_name text NOT NULL,
    outlet_name text NOT NULL,
    outlet_address_formatted text NOT NULL,
    outlet_timezone text NOT NULL,
    service_name text NOT NULL,
    service_duration_minutes integer NOT NULL,
    service_price_amount integer NOT NULL,
    currency text NOT NULL,
    deposit_type text NOT NULL,
    deposit_value integer NOT NULL,
    required_payment_amount integer NOT NULL,
    staff_name text NULL,
    cancellation_policy jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE booking_snapshots
ADD CONSTRAINT booking_snapshots_amount_check
CHECK (
    service_price_amount >= 0
    AND deposit_value >= 0
    AND required_payment_amount >= 0
);

ALTER TABLE booking_snapshots
ADD CONSTRAINT booking_snapshots_currency_check
CHECK (currency = 'IDR');

-- ---------------------------------------------------------------------------
-- booking_status_history (database-design §30)
-- ---------------------------------------------------------------------------
CREATE TABLE booking_status_history (
    id text PRIMARY KEY,
    booking_id text NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    from_status text NULL,
    to_status text NOT NULL,
    actor_user_id text NULL REFERENCES users(id),
    actor_type text NOT NULL,
    reason_code text NULL,
    reason text NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    request_id text NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX booking_status_history_booking_created_idx
ON booking_status_history(booking_id, created_at);

CREATE INDEX booking_status_history_request_idx
ON booking_status_history(request_id)
WHERE request_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- booking_reservations (ADR 0027 — overlap protection, total exclusion)
-- Row exists while the booking blocks the staff slot; deleted in the same
-- transaction that moves the booking to a non-blocking status.
-- ---------------------------------------------------------------------------
CREATE TABLE booking_reservations (
    booking_id text PRIMARY KEY REFERENCES bookings(id) ON DELETE CASCADE,
    staff_id text NOT NULL REFERENCES staff_profiles(id),
    outlet_id text NOT NULL REFERENCES outlets(id),
    schedule_range tstzrange NOT NULL,
    expires_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE booking_reservations
ADD CONSTRAINT booking_reservations_no_overlap
EXCLUDE USING gist (staff_id WITH =, schedule_range WITH &&);

CREATE INDEX booking_reservations_staff_idx
ON booking_reservations(staff_id);

-- ---------------------------------------------------------------------------
-- booking_code_counters (ADR 0038 — per-business daily sequence, atomic upsert)
-- ---------------------------------------------------------------------------
CREATE TABLE booking_code_counters (
    business_id text NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    business_date date NOT NULL,
    last_number integer NOT NULL DEFAULT 0,
    PRIMARY KEY (business_id, business_date)
);

-- ---------------------------------------------------------------------------
-- payments (database-design §32; ADR 0040 one pending online payment)
-- ---------------------------------------------------------------------------
CREATE TABLE payments (
    id text PRIMARY KEY,
    booking_id text NOT NULL REFERENCES bookings(id),
    business_id text NOT NULL REFERENCES businesses(id),
    customer_user_id text NULL REFERENCES users(id),
    provider text NOT NULL,
    provider_reference text NULL,
    payment_option text NOT NULL,
    method text NULL,
    status text NOT NULL,
    amount integer NOT NULL,
    currency text NOT NULL DEFAULT 'IDR',
    expires_at timestamptz NULL,
    paid_at timestamptz NULL,
    failed_at timestamptz NULL,
    cancelled_at timestamptz NULL,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE payments
ADD CONSTRAINT payments_status_check
CHECK (status IN (
    'pending',
    'paid',
    'failed',
    'expired',
    'cancelled',
    'refund_pending',
    'partially_refunded',
    'refunded'
));

ALTER TABLE payments
ADD CONSTRAINT payments_amount_check
CHECK (amount >= 0);

ALTER TABLE payments
ADD CONSTRAINT payments_currency_check
CHECK (currency = 'IDR');

ALTER TABLE payments
ADD CONSTRAINT payments_option_check
CHECK (payment_option IN ('pay_at_location', 'full_payment', 'deposit'));

CREATE UNIQUE INDEX payments_provider_reference_uq
ON payments(provider, provider_reference)
WHERE provider_reference IS NOT NULL;

-- ADR 0040: at most one pending online payment attempt per booking.
CREATE UNIQUE INDEX payments_one_pending_online_uq
ON payments(booking_id)
WHERE status = 'pending' AND provider <> 'pay_at_location';

CREATE INDEX payments_booking_created_idx
ON payments(booking_id, created_at);

CREATE INDEX payments_business_status_idx
ON payments(business_id, status, created_at);

CREATE INDEX payments_expiry_idx
ON payments(expires_at)
WHERE status = 'pending' AND expires_at IS NOT NULL;
