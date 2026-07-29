#!/bin/sh
# Deploy on the VPS: pull, migrate, restart. Run from this directory, or via
# `ssh vps 'cd /srv/antrein/deploy && ./deploy.sh'` (that is what CI does).
# Roll back to a known image: API_IMAGE=ghcr.io/inisialkey/antrein-api:<sha> ./deploy.sh
set -eu

cd "$(dirname "$0")"
COMPOSE="docker compose -f docker-compose.prod.yml"

$COMPOSE pull
# Migrations run to completion before the API restarts; a failure here stops the
# deploy with the old container still serving (ADR 0045 §5).
$COMPOSE --profile migrate run --rm migrate
$COMPOSE up -d
docker image prune -f

echo "Deployed. Health:"
$COMPOSE exec -T api wget -qO- http://127.0.0.1:3000/health/ready || echo "readiness check failed"
