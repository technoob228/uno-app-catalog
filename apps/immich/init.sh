#!/bin/sh
# Создаёт админа Immich (email владельца) через /api/auth/admin-sign-up.
set -eu
B=http://immich-server:2283/api
i=0
until curl -fsS "$B/server/ping" -o /dev/null 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "immich did not start in 10 minutes"; exit 1; }; sleep 2
done
if curl -fsS "$B/server/config" | grep -q '"isInitialized":true'; then
  echo "immich: already set up"; exit 0
fi
curl -fsS -X POST "$B/auth/admin-sign-up" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$OWNER_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"name\":\"Owner\"}" -o /dev/null
echo "immich: admin created"
