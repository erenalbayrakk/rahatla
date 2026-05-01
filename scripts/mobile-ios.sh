#!/usr/bin/env bash
# iOS Simülatörde Rahatla mobil uygulamasını çalıştırır.
# API varsayılan: http://localhost:3000 (Mac’te API aynı makinede ise)
#
# Kullanım:
#   ./scripts/mobile-ios.sh
#   API_BASE_URL=http://192.168.1.10:3000 ./scripts/mobile-ios.sh
#   ./scripts/mobile-ios.sh --release

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"
cd "$MOBILE"

export API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  open -a Simulator 2>/dev/null || true
fi

echo "→ API_BASE_URL=$API_BASE_URL"
flutter pub get
exec flutter run --dart-define=API_BASE_URL="$API_BASE_URL" "$@"
