-- M7 payment adapter + webhook: provider-creation tracking on payments,
-- payment_events (webhook dedupe/audit), refunds, refund_events.
-- database-design.md §32–§35, ADR 0040.

ALTER TABLE payments
    ADD COLUMN checkout jsonb NULL,
    ADD COLUMN provider_creation_attempts integer NOT NULL DEFAULT 0,
    ADD COLUMN provider_creation_last_error text NULL;

-- §33 Payment Events
CREATE TABLE payment_events (
    id text PRIMARY KEY,
    payment_id text NULL REFERENCES payments(id),
    provider text NOT NULL,
    provider_event_id text NOT NULL,
    event_type text NOT NULL,
    signature_valid boolean NOT NULL,
    amount integer NULL,
    currency text NULL,
    payload jsonb NOT NULL,
    processing_status text NOT NULL DEFAULT 'received',
    processing_error_code text NULL,
    processed_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE payment_events
ADD CONSTRAINT payment_events_processing_status_check
CHECK (processing_status IN ('received', 'processed', 'ignored', 'failed', 'manual_review'));

CREATE UNIQUE INDEX payment_events_provider_event_uq
ON payment_events(provider, provider_event_id);

CREATE INDEX payment_events_payment_created_idx
ON payment_events(payment_id, created_at);

CREATE INDEX payment_events_status_created_idx
ON payment_events(processing_status, created_at);

-- §34 Refunds
CREATE TABLE refunds (
    id text PRIMARY KEY,
    payment_id text NOT NULL REFERENCES payments(id),
    booking_id text NOT NULL REFERENCES bookings(id),
    business_id text NOT NULL REFERENCES businesses(id),
    requested_by_user_id text NULL REFERENCES users(id),
    provider_reference text NULL,
    status text NOT NULL,
    amount integer NOT NULL,
    currency text NOT NULL DEFAULT 'IDR',
    reason_code text NOT NULL,
    reason text NULL,
    requested_at timestamptz NOT NULL,
    processed_at timestamptz NULL,
    failed_at timestamptz NULL,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE refunds
ADD CONSTRAINT refunds_amount_check
CHECK (amount > 0);

ALTER TABLE refunds
ADD CONSTRAINT refunds_currency_check
CHECK (currency = 'IDR');

ALTER TABLE refunds
ADD CONSTRAINT refunds_status_check
CHECK (status IN (
    'refund_pending',
    'partially_refunded',
    'refunded',
    'failed',
    'cancelled'
));

CREATE UNIQUE INDEX refunds_provider_reference_uq
ON refunds(provider_reference)
WHERE provider_reference IS NOT NULL;

CREATE INDEX refunds_payment_created_idx
ON refunds(payment_id, created_at);

CREATE INDEX refunds_business_status_idx
ON refunds(business_id, status, created_at);

-- §35 Refund Events
CREATE TABLE refund_events (
    id text PRIMARY KEY,
    refund_id text NULL REFERENCES refunds(id),
    provider text NOT NULL,
    provider_event_id text NOT NULL,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    processing_status text NOT NULL DEFAULT 'received',
    processed_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX refund_events_provider_event_uq
ON refund_events(provider, provider_event_id);
