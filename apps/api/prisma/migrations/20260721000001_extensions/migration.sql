-- 001_extensions (docs/backend/database-design.md §82)
-- btree_gist: booking-overlap exclusion constraints (migration 009)
-- pg_trgm: business/service text search (migration 015)
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
