# Привязка входа через Uno владельца к админу Paperless (sso-link в compose).
# allauth заводит нового пользователя на каждый неизвестный uid и по email сам
# не связывает — без привязки владелец вошёл бы вторым, пустым аккаунтом.
import os
import sys
import time

sub = os.environ.get("UNO_OIDC_OWNER_SUB", "")
MEMBERS_GROUP = "Uno members"
if not os.environ.get("UNO_OIDC_CLIENT_ID") or not sub:
    print("uno-sso: Sign in with Uno is not configured for this install")
    sys.exit(0)

sys.path.insert(0, "/usr/src/paperless/src")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "paperless.settings")
import django  # noqa: E402

for attempt in range(300):
    try:
        django.setup()
        from django.contrib.auth.models import User
        from allauth.socialaccount.models import SocialAccount

        admin = User.objects.filter(username=os.environ.get("PAPERLESS_ADMIN_USER", "admin")).first()
        if admin is None:
            raise RuntimeError("admin is not created yet")
        acc, created = SocialAccount.objects.get_or_create(provider="uno", uid=sub, defaults={"user": admin})
        if acc.user_id != admin.id:
            print(f"uno-sso: {sub} is linked to another user ({acc.user_id}), leaving it")
        else:
            print("uno-sso: owner linked to admin" if created else "uno-sso: owner already linked")

        # Приглашённые через Uno («Share app») приходят без прав — Paperless
        # показал бы им «Error loading settings» и пустой архив. Группа с
        # правами на документы; новых в неё кладёт PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS,
        # уже заведённых — здесь. Управление пользователями (auth) не даём.
        from django.contrib.auth.models import Group, Permission

        group, _ = Group.objects.get_or_create(name=MEMBERS_GROUP)
        perms = Permission.objects.filter(content_type__app_label__in=["documents", "paperless_mail"])
        group.permissions.set(perms)
        for other in SocialAccount.objects.filter(provider="uno").exclude(user_id=admin.id):
            other.user.groups.add(group)
        print(f"uno-sso: {MEMBERS_GROUP} group ready ({perms.count()} permissions)")
        sys.exit(0)
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001 — ждём миграции/создание админа
        if attempt % 15 == 0:
            print(f"uno-sso: waiting for paperless ({e})")
        time.sleep(2)
print("uno-sso: paperless did not come up in 10 minutes")
sys.exit(1)
