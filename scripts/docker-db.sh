#!/usr/bin/env bash
# Sadece PostgreSQL konteynerini ayağa kaldırır (docker-compose).
#
# Kullanım:
#   ./scripts/docker-db.sh
#   ./scripts/docker-db.sh down

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" == "down" ]]; then
  docker compose down
  exit 0
fi

docker compose up -d postgres
echo "Postgres hazır (varsayılan: localhost:5432, kullanıcı rahatla)."
echo "API: cd apps/api && npm run start:dev"
