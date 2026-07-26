-- Reviews (database-design §44). One review per completed booking; rating
-- aggregates live on businesses/staff_profiles and are updated inside the
-- review transaction (ADR 0038).

CREATE TABLE reviews (
    id text PRIMARY KEY,
    booking_id text NOT NULL REFERENCES bookings(id),
    business_id text NOT NULL REFERENCES businesses(id),
    customer_user_id text NOT NULL REFERENCES users(id),
    staff_id text NULL REFERENCES staff_profiles(id),
    rating smallint NOT NULL,
    comment text NULL,
    status text NOT NULL DEFAULT 'published',
    moderated_at timestamptz NULL,
    moderated_by_user_id text NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE reviews
ADD CONSTRAINT reviews_rating_check
CHECK (rating BETWEEN 1 AND 5);

ALTER TABLE reviews
ADD CONSTRAINT reviews_status_check
CHECK (status IN ('published', 'hidden', 'removed'));

CREATE UNIQUE INDEX reviews_booking_uq
ON reviews(booking_id);

CREATE INDEX reviews_business_status_created_idx
ON reviews(business_id, status, created_at DESC);

CREATE INDEX reviews_staff_status_idx
ON reviews(staff_id, status)
WHERE staff_id IS NOT NULL;
