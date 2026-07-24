-- 004_business_and_catalog (docs/backend/database-design.md §13–§21, §47, §48)
-- Rating aggregates on businesses per ADR 0038 (stored, updated in review transaction).

CREATE TABLE businesses (
    id text PRIMARY KEY,
    owner_user_id text NOT NULL REFERENCES users(id),
    name text NOT NULL,
    slug text NOT NULL,
    description text NULL,
    logo_file_id text NULL,
    status text NOT NULL DEFAULT 'pending_verification',
    timezone text NOT NULL DEFAULT 'Asia/Jakarta',
    rating_average numeric(3,2) NOT NULL DEFAULT 0,
    rating_count integer NOT NULL DEFAULT 0,
    verified_at timestamptz NULL,
    suspended_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE businesses
ADD CONSTRAINT businesses_status_check
CHECK (status IN ('pending_verification', 'active', 'suspended', 'rejected', 'inactive'));

ALTER TABLE businesses
ADD CONSTRAINT businesses_rating_check
CHECK (rating_average BETWEEN 0 AND 5 AND rating_count >= 0);

CREATE UNIQUE INDEX businesses_slug_uq
ON businesses(slug);

CREATE INDEX businesses_status_idx
ON businesses(status);

-- One owned business per user (ADR 0026) — DB-enforced, not read-then-write.
CREATE UNIQUE INDEX businesses_owner_uq
ON businesses(owner_user_id);

CREATE TABLE business_policies (
    business_id text PRIMARY KEY REFERENCES businesses(id) ON DELETE CASCADE,
    minimum_lead_minutes integer NOT NULL DEFAULT 60,
    maximum_advance_days integer NOT NULL DEFAULT 30,
    automatic_confirmation boolean NOT NULL DEFAULT true,
    allow_pay_at_location boolean NOT NULL DEFAULT true,
    allow_full_payment boolean NOT NULL DEFAULT false,
    allow_deposit boolean NOT NULL DEFAULT false,
    default_deposit_type text NOT NULL DEFAULT 'none',
    default_deposit_value integer NOT NULL DEFAULT 0,
    full_refund_before_minutes integer NOT NULL DEFAULT 360,
    partial_refund_before_minutes integer NOT NULL DEFAULT 120,
    partial_refund_percentage integer NOT NULL DEFAULT 50,
    no_show_refund_percentage integer NOT NULL DEFAULT 0,
    check_in_early_minutes integer NOT NULL DEFAULT 30,
    check_in_late_minutes integer NOT NULL DEFAULT 15,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE business_policies
ADD CONSTRAINT business_policies_non_negative_check
CHECK (
    minimum_lead_minutes >= 0
    AND maximum_advance_days >= 0
    AND default_deposit_value >= 0
    AND full_refund_before_minutes >= 0
    AND partial_refund_before_minutes >= 0
    AND check_in_early_minutes >= 0
    AND check_in_late_minutes >= 0
);

ALTER TABLE business_policies
ADD CONSTRAINT business_policies_percentage_check
CHECK (
    partial_refund_percentage BETWEEN 0 AND 100
    AND no_show_refund_percentage BETWEEN 0 AND 100
);

ALTER TABLE business_policies
ADD CONSTRAINT business_policies_deposit_type_check
CHECK (default_deposit_type IN ('none', 'fixed', 'percentage'));

CREATE TABLE outlets (
    id text PRIMARY KEY,
    business_id text NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    phone_number text NULL,
    timezone text NOT NULL DEFAULT 'Asia/Jakarta',
    address_formatted text NOT NULL,
    latitude numeric(9,6) NULL,
    longitude numeric(9,6) NULL,
    status text NOT NULL DEFAULT 'active',
    queue_prefix text NOT NULL DEFAULT 'A',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE outlets
ADD CONSTRAINT outlets_status_check
CHECK (status IN ('active', 'inactive'));

ALTER TABLE outlets
ADD CONSTRAINT outlets_latitude_check
CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90);

ALTER TABLE outlets
ADD CONSTRAINT outlets_longitude_check
CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);

CREATE INDEX outlets_business_status_idx
ON outlets(business_id, status);

-- One active outlet per business in MVP (ADR 0038). Remove before multi-outlet release.
CREATE UNIQUE INDEX outlets_one_active_mvp_uq
ON outlets(business_id)
WHERE status = 'active';

CREATE TABLE business_memberships (
    id text PRIMARY KEY,
    business_id text NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role text NOT NULL,
    permissions jsonb NOT NULL DEFAULT '[]'::jsonb,
    status text NOT NULL DEFAULT 'active',
    joined_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE business_memberships
ADD CONSTRAINT business_memberships_role_check
CHECK (role IN ('owner', 'manager', 'barber', 'front_desk', 'cashier'));

ALTER TABLE business_memberships
ADD CONSTRAINT business_memberships_status_check
CHECK (status IN ('invited', 'active', 'inactive', 'suspended'));

CREATE UNIQUE INDEX business_memberships_business_user_uq
ON business_memberships(business_id, user_id);

CREATE INDEX business_memberships_user_status_idx
ON business_memberships(user_id, status);

CREATE INDEX business_memberships_business_status_idx
ON business_memberships(business_id, status);

CREATE TABLE staff_invitations (
    id text PRIMARY KEY,
    business_id text NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    email_normalized text NOT NULL,
    display_name text NOT NULL,
    role text NOT NULL,
    permissions jsonb NOT NULL DEFAULT '[]'::jsonb,
    outlet_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
    eligible_service_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
    token_hash text NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    invited_by_user_id text NOT NULL REFERENCES users(id),
    expires_at timestamptz NOT NULL,
    accepted_at timestamptz NULL,
    accepted_by_user_id text NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE staff_invitations
ADD CONSTRAINT staff_invitations_status_check
CHECK (status IN ('pending', 'accepted', 'expired', 'revoked'));

CREATE UNIQUE INDEX staff_invitations_token_hash_uq
ON staff_invitations(token_hash);

CREATE UNIQUE INDEX staff_invitations_pending_business_email_uq
ON staff_invitations(business_id, email_normalized)
WHERE status = 'pending';

CREATE INDEX staff_invitations_expires_idx
ON staff_invitations(expires_at)
WHERE status = 'pending';

CREATE TABLE staff_profiles (
    id text PRIMARY KEY,
    business_id text NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    membership_id text NOT NULL UNIQUE REFERENCES business_memberships(id) ON DELETE CASCADE,
    display_name text NOT NULL,
    avatar_file_id text NULL,
    staff_type text NOT NULL DEFAULT 'barber',
    status text NOT NULL DEFAULT 'active',
    rating_average numeric(3,2) NOT NULL DEFAULT 0,
    rating_count integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE staff_profiles
ADD CONSTRAINT staff_profiles_status_check
CHECK (status IN ('active', 'inactive', 'suspended'));

ALTER TABLE staff_profiles
ADD CONSTRAINT staff_profiles_rating_check
CHECK (rating_average BETWEEN 0 AND 5 AND rating_count >= 0);

CREATE INDEX staff_profiles_business_status_idx
ON staff_profiles(business_id, status);

CREATE TABLE staff_outlets (
    staff_id text NOT NULL REFERENCES staff_profiles(id) ON DELETE CASCADE,
    outlet_id text NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (staff_id, outlet_id)
);

CREATE TABLE services (
    id text PRIMARY KEY,
    business_id text NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name text NOT NULL,
    name_normalized text NOT NULL,
    description text NULL,
    image_file_id text NULL,
    duration_minutes integer NOT NULL,
    price_amount integer NOT NULL,
    currency text NOT NULL DEFAULT 'IDR',
    deposit_type text NOT NULL DEFAULT 'none',
    deposit_value integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'active',
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE services
ADD CONSTRAINT services_duration_check
CHECK (duration_minutes > 0);

ALTER TABLE services
ADD CONSTRAINT services_price_check
CHECK (price_amount >= 0);

ALTER TABLE services
ADD CONSTRAINT services_currency_check
CHECK (currency = 'IDR');

ALTER TABLE services
ADD CONSTRAINT services_deposit_type_check
CHECK (deposit_type IN ('none', 'fixed', 'percentage'));

ALTER TABLE services
ADD CONSTRAINT services_deposit_value_check
CHECK (
    deposit_value >= 0
    AND (deposit_type <> 'percentage' OR deposit_value BETWEEN 0 AND 100)
);

ALTER TABLE services
ADD CONSTRAINT services_status_check
CHECK (status IN ('active', 'inactive', 'archived'));

CREATE UNIQUE INDEX services_business_name_active_uq
ON services(business_id, name_normalized)
WHERE status <> 'archived';

CREATE INDEX services_business_status_sort_idx
ON services(business_id, status, sort_order);

CREATE TABLE staff_services (
    staff_id text NOT NULL REFERENCES staff_profiles(id) ON DELETE CASCADE,
    service_id text NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (staff_id, service_id)
);

CREATE TABLE idempotency_keys (
    id text PRIMARY KEY,
    scope_type text NOT NULL,
    scope_id text NOT NULL,
    action text NOT NULL,
    idempotency_key text NOT NULL,
    request_fingerprint text NOT NULL,
    status text NOT NULL,
    response_status integer NULL,
    response_body jsonb NULL,
    resource_type text NULL,
    resource_id text NULL,
    error_code text NULL,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE idempotency_keys
ADD CONSTRAINT idempotency_keys_status_check
CHECK (status IN ('processing', 'succeeded', 'failed_retryable', 'failed_final'));

CREATE UNIQUE INDEX idempotency_keys_scope_action_key_uq
ON idempotency_keys(scope_type, scope_id, action, idempotency_key);

CREATE INDEX idempotency_keys_expiry_idx
ON idempotency_keys(expires_at);

CREATE TABLE audit_logs (
    id text PRIMARY KEY,
    actor_user_id text NULL REFERENCES users(id),
    actor_type text NOT NULL,
    actor_role text NULL,
    business_id text NULL REFERENCES businesses(id),
    outlet_id text NULL REFERENCES outlets(id),
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id text NOT NULL,
    before_data jsonb NULL,
    after_data jsonb NULL,
    reason text NULL,
    request_id text NULL,
    ip_address inet NULL,
    user_agent text NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_logs_resource_idx
ON audit_logs(resource_type, resource_id, created_at);

CREATE INDEX audit_logs_business_created_idx
ON audit_logs(business_id, created_at DESC);

CREATE INDEX audit_logs_actor_created_idx
ON audit_logs(actor_user_id, created_at DESC)
WHERE actor_user_id IS NOT NULL;

CREATE INDEX audit_logs_request_idx
ON audit_logs(request_id)
WHERE request_id IS NOT NULL;
