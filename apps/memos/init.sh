#!/bin/sh
# Создаёт владельца Memos и закрывает регистрацию посторонних. С входом через
# аккаунт Uno (UNO_OIDC_*): провайдер «Uno», владелец привязан к своему
# аккаунту, новые аккаунты — только через Uno (владелец + «Share app»).
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
closed_signups() {
  curl -fsS -X PATCH "$B/instance/settings/GENERAL?updateMask=disallow_user_registration,disallow_password_auth" \
    -H "Authorization: Bearer $TOK" -H "$J" -o /dev/null \
    -d '{"name":"instance/settings/GENERAL","generalSetting":{"disallowUserRegistration":true,"disallowPasswordAuth":false}}'
}
if [ -z "${UNO_OIDC_CLIENT_ID:-}" ] || [ -z "${UNO_OIDC_CLIENT_SECRET:-}" ]; then
  closed_signups
  echo "memos: owner ready, sign-ups closed (no Sign in with Uno)"; exit 0
fi

# ---- Вход через аккаунт Uno ----
# Сбой здесь не закрывает приложение (front ждёт init): откатываемся к
# «регистрация закрыта, вход паролем» и выходим с 0.
sso_fail() { echo "memos: Sign in with Uno setup failed ($1) - password sign-in only"; closed_signups; exit 0; }
AUTHZ="Authorization: Bearer $TOK"
IDPS=$(curl -fsS "$B/identity-providers" -H "$AUTHZ") || sso_fail "list providers"
IDP=$(printf '%s' "$IDPS" | tr -d '\n' | sed -n 's/.*"name":"\(identity-providers\/[^"]*\)","type":"OAUTH2","title":"Uno".*/\1/p')
IDP_JSON=$(printf '{"type":"OAUTH2","title":"Uno","config":{"oauth2Config":{"clientId":"%s","clientSecret":"%s","authUrl":"%s","tokenUrl":"%s","userInfoUrl":"%s","scopes":["openid","email","profile"],"fieldMapping":{"identifier":"sub","displayName":"name","email":"email"}}}}' \
  "$UNO_OIDC_CLIENT_ID" "$UNO_OIDC_CLIENT_SECRET" "$UNO_OIDC_AUTH_URL" "$UNO_OIDC_TOKEN_URL" "$UNO_OIDC_USERINFO_URL")
if [ -z "$IDP" ]; then
  IDP=$(curl -fsS -X POST "$B/identity-providers" -H "$AUTHZ" -H "$J" -d "$IDP_JSON" \
    | tr -d '\n' | sed -n 's/.*"name":"\(identity-providers\/[^"]*\)".*/\1/p') || true
  [ -n "$IDP" ] || sso_fail "create provider"
else
  # Переустановка: тот же клиент, но секрет/адреса могли смениться.
  curl -fsS -X PATCH "$B/$IDP?updateMask=title,config" -H "$AUTHZ" -H "$J" -o /dev/null \
    -d "$(printf '%s' "$IDP_JSON" | sed "s#^{#{\"name\":\"$IDP\",#")" || sso_fail "update provider"
fi
# Владелец входит через Uno в СВОЙ аккаунт: привязываем identity к нему штатным
# обменом кода. Код владельца консоль выдаёт только по секрету клиента.
ME=$(curl -fsS "$B/auth/me" -H "$AUTHZ" | tr -d '\n' | sed -n 's/.*"name":"\(users\/[^"]*\)".*/\1/p')
[ -n "$ME" ] || sso_fail "who am I"
if ! curl -fsS "$B/$ME/linkedIdentities" -H "$AUTHZ" | grep -q "$IDP"; then
  CODE=$(curl -fsS -u "$UNO_OIDC_CLIENT_ID:$UNO_OIDC_CLIENT_SECRET" \
    --data-urlencode "redirect_uri=$MEMOS_INSTANCE_URL/auth/callback" "$UNO_OIDC_ISSUER/owner-code" \
    | sed -n 's/.*"code":"\([^"]*\)".*/\1/p')
  [ -n "$CODE" ] || sso_fail "owner code"
  curl -fsS -X POST "$B/$ME/linkedIdentities" -H "$AUTHZ" -H "$J" -o /dev/null \
    -d "{\"parent\":\"$ME\",\"idpName\":\"$IDP\",\"code\":\"$CODE\",\"redirectUri\":\"$MEMOS_INSTANCE_URL/auth/callback\"}" \
    || sso_fail "link owner"
fi
# Аккаунты заводятся только через Uno (регистрация паролем и вход паролем
# обычных пользователей закрыты; админ-владелец паролем входить может).
curl -fsS -X PATCH "$B/instance/settings/GENERAL?updateMask=disallow_user_registration,disallow_password_auth" \
  -H "$AUTHZ" -H "$J" -o /dev/null \
  -d '{"name":"instance/settings/GENERAL","generalSetting":{"disallowUserRegistration":false,"disallowPasswordAuth":true}}' \
  || sso_fail "settings"
echo "memos: owner ready, Sign in with Uno is on"
