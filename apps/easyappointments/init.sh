#!/bin/bash
# Устанавливает Easy!Appointments на ПУСТУЮ базу и сразу меняет сидовый пароль
# администратора («administrator») на сгенерированный Uno, email — на email
# владельца. На уже установленной базе ничего не делает (install = migrate
# fresh, он стёр бы данные).
set -euo pipefail
cd /var/www/html
# config.php и email.php — той же частью entrypoint'а образа, без запуска Apache.
sed '/^# Start Apache/,$d' /usr/local/bin/docker-entrypoint.sh > /tmp/ea-config.sh
bash /tmp/ea-config.sh
php -r '
$db = new mysqli(getenv("DB_HOST"), getenv("DB_USERNAME"), getenv("DB_PASSWORD"), getenv("DB_NAME"));
$r = $db->query("SHOW TABLES LIKE \"ea_users\"");
if ($r && $r->num_rows > 0 && $db->query("SELECT 1 FROM ea_users LIMIT 1")->num_rows > 0) { exit(10); }
exit(0);' && INSTALLED=0 || INSTALLED=$?
if [ "$INSTALLED" = "10" ]; then
  echo "easyappointments: already set up"; exit 0
fi
php index.php console install > /tmp/install.log 2>&1 || { cat /tmp/install.log; exit 1; }
php -r '
$db = new mysqli(getenv("DB_HOST"), getenv("DB_USERNAME"), getenv("DB_PASSWORD"), getenv("DB_NAME"));
$hash = password_hash(getenv("ADMIN_PASSWORD"), PASSWORD_BCRYPT, ["cost" => 12]);
$st = $db->prepare("UPDATE ea_user_settings SET password = ? WHERE username = \"administrator\"");
$st->bind_param("s", $hash); $st->execute();
if ($st->affected_rows !== 1) { fwrite(STDERR, "admin password not set\n"); exit(1); }
$email = getenv("OWNER_EMAIL");
$st = $db->prepare("UPDATE ea_users u JOIN ea_user_settings s ON s.id_users = u.id SET u.email = ?, u.first_name = \"Owner\", u.last_name = \"\" WHERE s.username = \"administrator\"");
$st->bind_param("s", $email); $st->execute();
$st = $db->prepare("UPDATE ea_settings SET value = ? WHERE name = \"company_email\"");
$st->bind_param("s", $email); $st->execute();
'
echo "easyappointments: installed, admin password set"
