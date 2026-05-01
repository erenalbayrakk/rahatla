# Rahatla — kısayol komutları (proje kökünden)
#
#   make docker         # Postgres + API + Prisma Studio (docker compose up -d --build)
#                       # API: http://localhost:${API_PORT:-3000}  Studio: http://localhost:${PRISMA_STUDIO_PORT:-5555}
#   make seed-test-listener-applicants  # test1@test.com … test40 (şifre 12345678, listener_applicant)
#   make docker-down    # Tüm konteynerleri durdur
#   make docker-logs veya make logs
#   make docker-logs-api / docker-logs-db
#   make docker-db      # Sadece Postgres
#   make mobile-ios     # iOS Simulator + flutter run
#   make mobile-android # Android emülatör + flutter run
#   make mobile-devices # Bağlı cihazları listele

.PHONY: docker docker-down docker-logs docker-logs-api docker-logs-db logs docker-db docker-db-down seed-test-listener-applicants mobile-ios mobile-android mobile-devices mobile-pub-get

# Dinleyen adayı test kullanıcıları test1..test40 (apps/api/.env → DATABASE_URL)
seed-test-listener-applicants:
	cd apps/api && npm run seed:test-listener-applicants

docker:
	docker compose up -d --build

docker-down:
	docker compose down

docker-logs:
	docker compose logs -f

docker-logs-api:
	docker compose logs -f api

docker-logs-db:
	docker compose logs -f postgres

# `make docker logs` değil — ayrı: `make docker-logs` veya `make logs`
logs: docker-logs

docker-db:
	bash scripts/docker-db.sh

docker-db-down:
	bash scripts/docker-db.sh down

mobile-ios:
	bash scripts/mobile-ios.sh

mobile-android:
	bash scripts/mobile-android.sh

mobile-devices:
	cd apps/mobile && flutter devices

mobile-pub-get:
	cd apps/mobile && flutter pub get
