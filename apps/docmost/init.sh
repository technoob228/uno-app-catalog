#!/bin/sh
# Создаёт рабочее пространство и админа Docmost (email владельца).
set -eu
B=http://docmost:3000/api
J='Content-Type: application/json'
LOGIN="{\"email\":\"$OWNER_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}"
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "$B/health" || true)" = "200" ]; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "docmost did not start in 10 minutes"; exit 1; }; sleep 2
done
if [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/auth/login" -H "$J" -d "$LOGIN")" = "200" ]; then
  echo "docmost: already set up"; exit 0
fi
curl -fsS -X POST "$B/auth/setup" -H "$J" -o /dev/null \
  -d "{\"name\":\"Owner\",\"email\":\"$OWNER_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"workspaceName\":\"My workspace\"}"
echo "docmost: workspace and admin created"
