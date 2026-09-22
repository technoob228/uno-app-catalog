#!/bin/sh
# Создаёт админа Pingvin Share (email владельца) и закрывает регистрацию.
set -eu
B=http://pingvin:3000/api
J='Content-Type: application/json'
i=0
until curl -fsS "$B/configs" -o /dev/null 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "pingvin did not start in 10 minutes"; exit 1; }; sleep 2
done
signin() {
  curl -s -c - -X POST "$B/auth/signIn" -H "$J" \
    -d "{\"email\":\"$OWNER_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | awk '$6=="access_token"{print $7}'
}
TOK=$(signin)
if [ -z "$TOK" ]; then
  curl -fsS -X POST "$B/auth/signUp" -H "$J" -o /dev/null \
    -d "{\"email\":\"$OWNER_EMAIL\",\"username\":\"owner\",\"password\":\"$ADMIN_PASSWORD\"}"
  TOK=$(signin)
fi
[ -n "$TOK" ] || { echo "pingvin: owner login failed"; exit 1; }
curl -fsS -X PATCH "$B/configs/admin" -H "Cookie: access_token=$TOK" -H "$J" -o /dev/null \
  -d '[{"key":"share.allowRegistration","value":false}]'
echo "pingvin: admin ready, sign-ups closed"
