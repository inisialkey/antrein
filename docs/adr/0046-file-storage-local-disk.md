# ADR 0046 — File storage on local disk, served through the API

- **Status**: Accepted
- **Date**: 2026-08-06
- **Supersedes**: none
- **Amends**: ADR 0045 (§4 "object storage is not deployed")

## Context

The `files` module was the last gap blocking image upload: business logos,
service photos and customer avatars all had `*_file_id` columns and DTO fields,
but nothing wrote or validated them and every mapper returned `null`.

ADR 0045 deferred object storage because no consumer existed. One exists now.
The deployment is still a single VPS running one API container behind Caddy
(ADR 0045), and the MVP's images are small, public and few: a logo per business,
a photo per service, an avatar per user.

## Decision

1. **Local disk behind `ObjectStoragePort`, not a bucket.** `STORAGE_PROVIDER`
   selects the adapter exactly like `PAYMENT_PROVIDER` and `PUSH_PROVIDER`;
   `local` is the only implementation. Files land under `STORAGE_LOCAL_ROOT`,
   a named Docker volume in production. An S3/MinIO adapter is a drop-in
   replacement behind the port the day a second API instance exists — that is
   the same trigger as Redis (ADR 0036).

   MinIO stays a local-only compose service and is now unused; it is kept so the
   bucket adapter has somewhere to run when it is written.

2. **The API serves the bytes: `GET /files/{fileId}/content` (contract §37.1).**
   Public, unauthenticated, cacheable. The opaque ULID is the access control,
   the same reasoning as the booking code — knowing an id is not permission for
   anything that matters, and these images are shown on public discovery pages
   anyway. This adds one endpoint but removes a static-file mount, a second
   hostname, and any Caddy change; `PUBLIC_API_URL` is the only new coupling.

3. **No `file_attachments` table.** database-design §46 specifies a join table,
   but every owning resource already carries a `*_file_id` column that this ADR
   puts under a foreign key. Two records of the same fact is a sync bug waiting
   to happen. `files.status` records *whether* a file is attached; the pointer
   column records *where*. The table is created when a purpose needs many files
   per resource — `business_gallery` is the obvious one, and it has no endpoint
   in v1.

4. **Content is validated by magic bytes, not by the declared type.** A
   `Content-Type` header is client input. Since the API serves these bytes back
   under its own origin, the first three/eight/twelve bytes must match one of
   JPEG, PNG or WebP or the upload is rejected `FILE_INVALID_CONTENT`.

5. **Attachment is validated, cross-module, through `FilesService.attach`.**
   Owning modules (users, businesses, services, staff) call it inside their own
   transaction; it checks ownership, marks the file `attached`, and releases the
   file it replaces so that orphan stays deletable. No module writes the `files`
   table directly.

## Consequences

- Uploads survive redeploys only because of the named volume; losing it loses
  every image. The backup script covers the database, not the volume — restoring
  images means restoring the volume, and `docs/ops/runbook.md` says so.
- One container can write the volume. A second API instance requires the bucket
  adapter first; this is now the second thing gated on that (Redis is the first).
- File URLs embed `PUBLIC_API_URL`. Changing the API domain invalidates every
  URL already delivered to a client. The ids are stable, so a domain move is a
  config change plus a client refresh, not a data migration.
- An abandoned form leaves an unattached `ready` file behind. The
  `files_unattached_cleanup_idx` index exists for the sweep; the job does not,
  and at MVP volume the disk cost is noise. Write it when the volume grows or
  when a purge policy is decided (data retention is still open).
- `users.phone_number_normalized` is now populated on registration as well as on
  `PATCH /me`, so `USER_PHONE_ALREADY_USED` is enforced by the unique index that
  already existed rather than by a read-then-write check.
