#!/bin/sh
# Создаёт админа Jellyfin через API мастера первого входа и медиатеку /media.
set -eu
B=http://jellyfin:8096
AUTH='MediaBrowser Client="Uno", Device="uno-install", DeviceId="uno-install", Version="1.0"'
i=0
until curl -fsS "$B/System/Info/Public" -o /tmp/info 2>/dev/null; do
  i=$((i+1)); [ "$i" -gt 300 ] && { echo "jellyfin did not start in 10 minutes"; exit 1; }; sleep 2
done
if grep -q '"StartupWizardCompleted":true' /tmp/info; then
  echo "jellyfin: already set up"; exit 0
fi
J='Content-Type: application/json'
# Jellyfin отвечает 503, пока дожимает запуск (миграции) — повторяем шаги.
req() {
  n=0
  until curl -fsS "$@"; do
    n=$((n+1)); [ "$n" -gt 100 ] && return 1; sleep 3
  done
}
req "$B/Startup/Configuration" -o /dev/null
curl -fsS -X POST "$B/Startup/Configuration" -H "$J" -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
req "$B/Startup/User" -o /dev/null
curl -fsS -X POST "$B/Startup/User" -H "$J" -d "{\"Name\":\"$ADMIN_USER\",\"Password\":\"$ADMIN_PASSWORD\"}"
curl -fsS -X POST "$B/Startup/RemoteAccess" -H "$J" -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'
curl -fsS -X POST "$B/Startup/Complete"
TOKEN=$(curl -fsS -X POST "$B/Users/AuthenticateByName" -H "Authorization: $AUTH" -H "$J" \
  -d "{\"Username\":\"$ADMIN_USER\",\"Pw\":\"$ADMIN_PASSWORD\"}" | sed -n 's/.*"AccessToken":"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] || { echo "jellyfin: admin login failed after setup"; exit 1; }
curl -fsS -X POST "$B/Library/VirtualFolders?name=Media&collectionType=movies&refreshLibrary=true" \
  -H "Authorization: $AUTH, Token=\"$TOKEN\"" -H "$J" -d '{"LibraryOptions":{"PathInfos":[{"Path":"/media"}]}}' \
  || echo "jellyfin: could not add the Media library (add it in Dashboard → Libraries)"
echo "jellyfin: admin created"
