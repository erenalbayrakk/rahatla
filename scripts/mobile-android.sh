#!/usr/bin/env bash
# Android emülatörde Rahatla mobil uygulamasını çalıştırır.
# API varsayılan: http://10.0.2.2:3000 (host makinedeki :3000)
#
# Kullanım:
#   ./scripts/mobile-android.sh
#   API_BASE_URL=http://10.0.2.2:3000 ./scripts/mobile-android.sh
#   ./scripts/mobile-android.sh -d emulator-5554

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"
cd "$MOBILE"

export API_BASE_URL="${API_BASE_URL:-http://10.0.2.2:3000}"

echo "→ API_BASE_URL=$API_BASE_URL"
echo "→ Emülatör açık ve listede görünüyor olmalı: flutter devices"
flutter pub get
exec flutter run --dart-define=API_BASE_URL="$API_BASE_URL" "$@"
