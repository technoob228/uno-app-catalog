// Вход в Immich через аккаунт Uno: включает OAuth в системных настройках
// Immich (через API админа, а не файлом — иначе настройки в интерфейсе стали бы
// только для чтения). Идемпотентно, на каждом `compose up`. Без
// UNO_OIDC_CLIENT_ID (консоль без входа через Uno) — ничего не делает.
// Владелец попадает в админа по email (Immich связывает OAuth с существующим
// пользователем с тем же email); приглашённые заводятся сами (autoRegister).
// Запасной вход паролем: <адрес>/auth/login?autoLaunch=0
const B = 'http://immich-server:2283/api';
const env = process.env;
if (!env.UNO_OIDC_CLIENT_ID || !env.UNO_OIDC_CLIENT_SECRET) {
  console.log('uno-sso: Sign in with Uno is not configured for this install');
  process.exit(0);
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function call(method, path, token, body) {
  const res = await fetch(B + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}
// Сбой настройки SSO не должен закрыть приложение: front ждёт этот шаг, и
// упавший шаг оставил бы адрес без ответа. Не вышло — вход паролем, exit 0.
try {
for (let i = 0; ; i++) {
  try { await call('GET', '/server/ping'); break; } catch (e) {
    if (i > 300) throw new Error('immich did not start in 10 minutes');
    await sleep(2000);
  }
}
const login = await call('POST', '/auth/login', null, { email: env.OWNER_EMAIL, password: env.ADMIN_PASSWORD });
const cfg = await call('GET', '/admin/config', login.accessToken);
cfg.oauth = {
  ...cfg.oauth,
  enabled: true,
  issuerUrl: env.UNO_OIDC_ISSUER,
  clientId: env.UNO_OIDC_CLIENT_ID,
  clientSecret: env.UNO_OIDC_CLIENT_SECRET,
  scope: 'openid email profile',
  tokenEndpointAuthMethod: 'client_secret_post',
  signingAlgorithm: 'RS256',
  autoRegister: true,
  autoLaunch: true,
  buttonText: 'Sign in with Uno',
};
cfg.passwordLogin = { ...cfg.passwordLogin, enabled: true };
await call('PUT', '/admin/config', login.accessToken, cfg);
console.log('uno-sso: Sign in with Uno is on');
} catch (e) {
  console.error(`uno-sso: could not turn on Sign in with Uno (password sign-in still works): ${e.message}`);
}
