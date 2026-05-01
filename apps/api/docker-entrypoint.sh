#!/bin/sh
set -e

if [ "${RELEASE_COMMAND:-}" = "1" ]; then
  exec "$@"
fi

echo "Running Prisma migrate deploy..."
npx prisma migrate deploy
exec "$@"
