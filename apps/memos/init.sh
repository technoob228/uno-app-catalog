#!/bin/sh
# Создаёт владельца Memos и закрывает регистрацию посторонних.
set -eu
B=http://memos:5230/api/v1
J='Content-Type: application/json'
i=0
until curl -fsS "$B/instance/profile" -o /dev/null 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "memos did not start in 10 minutes"; exit 1; }; sleep 2
done
signin() {
  curl -s -X POST "$B/auth/signin" -H "$J" \
    -d "{\"passwordCredentials\":{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASSWORD\"}}" \
    | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p'
}
TOK=$(signin)
if [ -z "$TOK" ]; then
  curl -fsS -X POST "$B/users" -H "$J" -o /dev/null \
    -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASSWORD\",\"role\":\"ADMIN\"}"
  TOK=$(signin)
fi
[ -n "$TOK" ] || { echo "memos: owner login failed"; exit 1; }
curl -fsS -X PATCH "$B/instance/settings/GENERAL?updateMask=disallow_user_registration" \
  -H "Authorization: Bearer $TOK" -H "$J" -o /dev/null \
  -d '{"name":"instance/settings/GENERAL","generalSetting":{"disallowUserRegistration":true}}'
echo "memos: owner ready, sign-ups closed"
