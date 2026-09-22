#!/bin/bash
# Ждёт, пока веб-контейнер Lychee накатит миграции и поднимется, и создаёт
# админа (admin, пароль от Uno). Если admin уже есть — ничего не делает.
set -euo pipefail
cd /app
export APP_KEY="$(cat "$APP_KEY_FILE")"
i=0
until curl -s -o /dev/null -m 3 http://lychee:8000/; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "lychee did not start in 10 minutes"; exit 1; }; sleep 2
done
COUNT=$(php -r '$db = new PDO("sqlite:" . getenv("DB_DATABASE")); echo $db->query("SELECT COUNT(*) FROM users WHERE username = \"admin\"")->fetchColumn();')
if [ "$COUNT" != "0" ]; then
  echo "lychee: already set up"; exit 0
fi
gosu www-data php artisan lychee:create_user admin "$ADMIN_PASSWORD" --may-administrate --may-upload
echo "lychee: admin created"
