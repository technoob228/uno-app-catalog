#!/bin/sh
# Регистрирует владельца (owner) по коду приглашения — первый пользователь
# Tuwunel становится админом сервера.
set -eu
B=http://tuwunel:6167/_matrix/client/v3
J='Content-Type: application/json'
i=0
until curl -fsS "http://tuwunel:6167/_matrix/client/versions" -o /dev/null 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "tuwunel did not start in 10 minutes"; exit 1; }; sleep 2
done
LOGIN="{\"type\":\"m.login.password\",\"identifier\":{\"type\":\"m.id.user\",\"user\":\"$ADMIN_USER\"},\"password\":\"$ADMIN_PASSWORD\"}"
if [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/login" -H "$J" -d "$LOGIN")" = "200" ]; then
  echo "chat: already set up"; exit 0
fi
REG="\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASSWORD\",\"inhibit_login\":true"
SESSION=$(curl -s -X POST "$B/register" -H "$J" -d "{$REG}" | sed -n 's/.*"session":"\([^"]*\)".*/\1/p')
[ -n "$SESSION" ] || { echo "chat: registration did not start a session"; exit 1; }
curl -fsS -X POST "$B/register" -H "$J" -o /dev/null \
  -d "{$REG,\"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$INVITE_CODE\",\"session\":\"$SESSION\"}}"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/login" -H "$J" -d "$LOGIN")" = "200" ] \
  || { echo "chat: owner login failed"; exit 1; }
echo "chat: owner created"
