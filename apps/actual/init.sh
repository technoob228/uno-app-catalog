#!/bin/sh
# Задаёт пароль сервера Actual (bootstrap).
set -eu
B=http://actual:5006
i=0
until curl -fsS "$B/account/needs-bootstrap" -o /tmp/nb 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "actual did not start in 10 minutes"; exit 1; }; sleep 2
done
if grep -q '"bootstrapped":true' /tmp/nb; then
  echo "actual: already set up"; exit 0
fi
curl -fsS -X POST "$B/account/bootstrap" -H 'Content-Type: application/json' -o /dev/null \
  -d "{\"password\":\"$ADMIN_PASSWORD\"}"
echo "actual: server password set"
