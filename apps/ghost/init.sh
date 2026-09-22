#!/bin/sh
# Создаёт владельца сайта Ghost через Admin API setup (пока его нет).
set -eu
B=http://ghost:2368/ghost/api/admin
# Ghost сверяет схему и хост с url сайта: говорим как прокси ноды.
H1="X-Forwarded-Proto: https"
H2="Host: ${APP_HOST}"
i=0
until curl -fsS -H "$H1" -H "$H2" "$B/authentication/setup/" -o /tmp/setup 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "ghost did not start in 10 minutes"; exit 1; }; sleep 2
done
if grep -q '"status":true' /tmp/setup; then
  echo "ghost: already set up"; exit 0
fi
curl -fsS -X POST "$B/authentication/setup/" -H "$H1" -H "$H2" -H 'Content-Type: application/json' -o /dev/null \
  -d "{\"setup\":[{\"name\":\"Owner\",\"email\":\"$OWNER_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"blogTitle\":\"My site\"}]}"
echo "ghost: owner created"
