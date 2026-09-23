#!/bin/sh
# Вход в Nextcloud через аккаунт Uno (user_oidc). Хук before-starting образа
# nextcloud: выполняется от www-data на КАЖДОМ старте, поэтому идемпотентен
# (переустановка поверх данных, смена секрета — всё перенастраивается).
# Без UNO_OIDC_CLIENT_ID (консоль без входа через Uno) — ничего не делает.
# Владелец входит в админа «admin»: user_oidc связывает по uid, консоль отдаёт
# ему preferred_username=admin; приглашённые получают свои аккаунты.
# Запасной вход паролем: <адрес>/login?direct=1
# Хук НИКОГДА не падает: упавший before-starting останавливает весь Nextcloud
# (entrypoint образа делает exit 1) — лучше вход паролем, чем лежащее приложение.
set -u
if [ -z "${UNO_OIDC_CLIENT_ID:-}" ] || [ -z "${UNO_OIDC_CLIENT_SECRET:-}" ]; then
  echo "uno-sso: Sign in with Uno is not configured for this install"; exit 0
fi
occ() { php /var/www/html/occ "$@"; }
if ! occ status 2>/dev/null | grep -q "installed: true"; then
  echo "uno-sso: nextcloud is not installed yet, skipping"; exit 0
fi
if ! occ app:list 2>/dev/null | grep -q "user_oidc"; then
  occ app:install user_oidc || occ app:enable user_oidc || {
    echo "uno-sso: could not install user_oidc (no access to apps.nextcloud.com?) - password sign-in only"; exit 0; }
fi
occ app:enable user_oidc >/dev/null 2>&1 || true
occ user_oidc:provider Uno \
  --clientid="$UNO_OIDC_CLIENT_ID" \
  --clientsecret="$UNO_OIDC_CLIENT_SECRET" \
  --discoveryuri="$UNO_OIDC_DISCOVERY_URL" \
  --scope="openid email profile" \
  --unique-uid=0 \
  --mapping-uid=preferred_username \
  --mapping-email=email \
  --mapping-display-name=name \
  --check-bearer=0 \
  --send-id-token-hint=1 >/dev/null || { echo "uno-sso: provider setup failed - password sign-in only"; exit 0; }
# Один провайдер и без «других бэкендов» — страница входа сразу уходит в Uno.
occ config:app:set --type=string --value=0 user_oidc allow_multiple_user_backends >/dev/null || true
echo "uno-sso: Sign in with Uno is on"
exit 0
