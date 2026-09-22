#!/bin/sh
# Создаёт аккаунт владельца Vikunja напрямую (минуя ворота регистрации).
set -eu
B=http://vikunja:3456/api/v1
J='Content-Type: application/json'
i=0
until curl -fsS "$B/info" -o /dev/null 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "vikunja did not start in 10 minutes"; exit 1; }; sleep 2
done
LOGIN="{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASSWORD\"}"
if [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/login" -H "$J" -d "$LOGIN")" = "200" ]; then
  echo "vikunja: already set up"; exit 0
fi
curl -fsS -X POST "$B/register" -H "$J" -o /dev/null \
  -d "{\"username\":\"$ADMIN_USER\",\"email\":\"$OWNER_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/login" -H "$J" -d "$LOGIN")" = "200" ] \
  || { echo "vikunja: owner login failed"; exit 1; }
echo "vikunja: owner created"
