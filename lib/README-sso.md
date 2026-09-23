# Вход через аккаунт Uno (SSO)

Консоль Uno — OpenID Connect-провайдер (issuer `https://console.uno4.dev/api/v1/oidc`).
Установка приложения с `sso.mode: oidc` в каталоге консоли регистрирует его
клиентом и передаёт переменные:

| переменная | что это |
|---|---|
| `UNO_OIDC_ISSUER` | issuer (discovery = issuer + `/.well-known/openid-configuration`) |
| `UNO_OIDC_DISCOVERY_URL` | полный адрес discovery |
| `UNO_OIDC_AUTH_URL` / `_TOKEN_URL` / `_USERINFO_URL` | для приложений без discovery (Memos) |
| `UNO_OIDC_CLIENT_ID` / `UNO_OIDC_CLIENT_SECRET` | клиент этой установки (один на бокс+приложение) |
| `UNO_OIDC_OWNER_SUB` | `sub` владельца — привязать его к админу, созданному установкой |

Правила для планов:

- Пустой `UNO_OIDC_CLIENT_ID` — консоль без SSO: план обязан работать как раньше
  (вход паролем).
- Сбой настройки SSO НЕ закрывает приложение: шаги SSO выходят с 0 и пишут в лог
  («password sign-in only»). Иначе ворота (`front`) не откроют адрес.
- Пароль админа из карточки остаётся запасным входом.
- Владелец должен попасть в СВОЙ аккаунт (админа), а не во второй пустой:
  по email (Open WebUI, Immich, Vikunja), по логину (`owner_username` в каталоге —
  Nextcloud), по `UNO_OIDC_OWNER_SUB` (Paperless) или через `POST {issuer}/owner-code`
  (код владельца по секрету клиента → штатная привязка приложения, Memos).
- Пускает только Uno: владелец бокса и те, с кем он поделился приложением
  («Share app» в Uno Work). Приглашённые получают `preferred_username` вида
  `<логин>-<id>` — он никогда не совпадает с логином админа приложения.
- «Open» из Uno Work ведёт на `sso.login_path` — адрес, с которого приложение
  сразу уходит во вход через Uno. Если приложение так не умеет (Memos, Vikunja),
  план отдаёт `/uno-login` (Caddy), которая начинает вход так же, как кнопка
  на странице входа приложения.

Приложения без OIDC закрываются на edge ноды (`sso.mode: edge`, forward-auth в
консоль) — план для этого менять не нужно.
