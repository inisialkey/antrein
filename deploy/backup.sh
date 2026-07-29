#!/bin/sh
# Nightly PostgreSQL dump (backend-brief §95). Install on the VPS with:
#   0 3 * * * /srv/antrein/deploy/backup.sh >> /var/log/antrein-backup.log 2>&1
# Restore is documented in docs/ops/runbook.md — rehearse it quarterly.
set -eu

cd "$(dirname "$0")"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/antrein}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)

# Read the two values needed straight out of .env — sourcing it would execute
# lines like `EMAIL_FROM=AntreIn <no-reply@…>` as shell redirects.
POSTGRES_USER=$(sed -n 's/^POSTGRES_USER=//p' .env | head -1)
POSTGRES_DB=$(sed -n 's/^POSTGRES_DB=//p' .env | head -1)
: "${POSTGRES_USER:?POSTGRES_USER missing from .env}"
: "${POSTGRES_DB:?POSTGRES_DB missing from .env}"

mkdir -p "$BACKUP_DIR"
docker compose -f docker-compose.prod.yml exec -T postgres \
	pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom \
	| gzip >"$BACKUP_DIR/antrein-$STAMP.dump.gz"

# Fail loudly on an empty dump instead of silently keeping a useless file.
if [ ! -s "$BACKUP_DIR/antrein-$STAMP.dump.gz" ]; then
	rm -f "$BACKUP_DIR/antrein-$STAMP.dump.gz"
	echo "backup failed: empty dump" >&2
	exit 1
fi

find "$BACKUP_DIR" -name 'antrein-*.dump.gz' -mtime "+$RETENTION_DAYS" -delete
echo "backup ok: $BACKUP_DIR/antrein-$STAMP.dump.gz"
