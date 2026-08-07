-- Files (database-design §45). The owning resources already carry
-- `*_file_id` pointers (users, businesses, services, staff_profiles), so the
-- design's `file_attachments` join table is deliberately not created — ADR
-- 0046. `files.status` records attachment; the pointer column records where.

CREATE TABLE files (
    id text PRIMARY KEY,
    owner_user_id text NOT NULL REFERENCES users(id),
    purpose text NOT NULL,
    storage_provider text NOT NULL,
    storage_key text NOT NULL,
    mime_type text NOT NULL,
    size_bytes bigint NOT NULL,
    checksum text NULL,
    visibility text NOT NULL DEFAULT 'private',
    status text NOT NULL DEFAULT 'pending',
    original_filename text NULL,
    width integer NULL,
    height integer NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz NULL
);

ALTER TABLE files
ADD CONSTRAINT files_size_check
CHECK (size_bytes >= 0);

ALTER TABLE files
ADD CONSTRAINT files_visibility_check
CHECK (visibility IN ('private', 'public'));

ALTER TABLE files
ADD CONSTRAINT files_status_check
CHECK (status IN ('pending', 'ready', 'attached', 'failed', 'deleted'));

ALTER TABLE files
ADD CONSTRAINT files_purpose_check
CHECK (purpose IN (
    'customer_avatar',
    'business_logo',
    'business_gallery',
    'staff_avatar',
    'service_image'
));

CREATE UNIQUE INDEX files_storage_key_uq
ON files(storage_provider, storage_key);

CREATE INDEX files_unattached_cleanup_idx
ON files(status, created_at)
WHERE status IN ('pending', 'ready', 'failed');

CREATE INDEX files_owner_idx
ON files(owner_user_id, created_at DESC);

-- The pointer columns predate this table; constrain them now that the target
-- exists. Deletes are soft (status='deleted'), so no ON DELETE action applies.
ALTER TABLE users
ADD CONSTRAINT users_avatar_file_fk
FOREIGN KEY (avatar_file_id) REFERENCES files(id);

ALTER TABLE businesses
ADD CONSTRAINT businesses_logo_file_fk
FOREIGN KEY (logo_file_id) REFERENCES files(id);

ALTER TABLE staff_profiles
ADD CONSTRAINT staff_profiles_avatar_file_fk
FOREIGN KEY (avatar_file_id) REFERENCES files(id);

ALTER TABLE services
ADD CONSTRAINT services_image_file_fk
FOREIGN KEY (image_file_id) REFERENCES files(id);
