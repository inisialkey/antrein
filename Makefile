API_DIR = apps/api
TEST_DATABASE_URL = postgresql://postgres:postgres@localhost:5432/antrein_test

.PHONY: bootstrap dev test test-integration migrate seed

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
