API_DIR = apps/api
MOBILE_DIR = apps/mobile
TEST_DATABASE_URL = postgresql://postgres:postgres@localhost:5432/antrein_test

.PHONY: bootstrap dev test test-integration migrate seed seed-demo docker-build mobile-reverse mobile-dev mobile-staging mobile-production

bootstrap:
	cd $(API_DIR) && npm install
	test -f $(API_DIR)/.env || cp .env.example $(API_DIR)/.env
	docker compose up -d --wait postgres redis minio mailpit
	cd $(API_DIR) && npx prisma migrate deploy && npx prisma generate

dev:
	docker compose up -d --wait postgres redis minio mailpit
	cd $(API_DIR) && npm run start:dev

test:
	cd $(API_DIR) && npm run test

test-integration:
	docker compose up -d --wait postgres
	docker exec antrein-postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='antrein_test'" | grep -q 1 || docker exec antrein-postgres createdb -U postgres antrein_test
	cd $(API_DIR) && DATABASE_URL=$(TEST_DATABASE_URL) npx prisma migrate deploy
	cd $(API_DIR) && DATABASE_URL=$(TEST_DATABASE_URL) npm run test:integration

migrate:
	cd $(API_DIR) && npx prisma migrate deploy

seed:
	cd $(API_DIR) && npm run seed

# Demo catalog + logins (ADR 0045); point DATABASE_URL at the target database.
seed-demo:
	cd $(API_DIR) && npm run seed:demo

# Same build CI and the VPS run — catches Dockerfile breakage locally.
docker-build:
	cd $(API_DIR) && docker build --build-arg GIT_SHA=$$(git rev-parse --short HEAD) -t antrein-api:local .

# dev.json targets localhost, so every device/emulator needs the API forwarded
# over adb. Beats a LAN IP: survives DHCP changes, VPNs and guest-Wi-Fi
# isolation, all of which surface as a bare `connectionError` in the app.
# The tunnel is per-device and dies with the connection — re-run after every
# replug, emulator restart or `adb kill-server`. Plain `adb reverse` fails as
# soon as a second device appears, hence the loop.
mobile-reverse:
	@adb devices | awk 'NR>1 && $$2=="device" {print $$1}' | while read -r d; do \
		adb -s "$$d" reverse tcp:3000 tcp:3000 >/dev/null && echo "reverse ready: $$d"; \
	done

# Flavors carry dart-defines only — no native productFlavors, so no --flavor flag.
# Two devices? Run mobile-reverse, then `flutter run -d <serial>` per device.
mobile-dev: mobile-reverse
	cd $(MOBILE_DIR) && flutter run -t lib/main_dev.dart --dart-define-from-file=config/flavors/dev.json

mobile-staging:
	cd $(MOBILE_DIR) && flutter run -t lib/main_staging.dart --dart-define-from-file=config/flavors/staging.json

mobile-production:
	cd $(MOBILE_DIR) && flutter run -t lib/main_production.dart --dart-define-from-file=config/flavors/production.json
