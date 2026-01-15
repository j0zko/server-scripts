#!/bin/bash

ADMIN_USER="sysadmin"
ADMIN_PASS="Admin123"
USER_REGULAR="student"
USER_REGULAR_PASS="Student123"
BACKUP_USER="backupuser"
BACKUP_PASS="BackupPass123"

set -e

add_users_if_missing() {
  local u=$1
  local p=$2
  if id "$u" >/dev/null 2>&1; then
    echo "Pouzivatel $u uz existuje"
  else
    useradd -m -s /bin/bash "$u"
    echo "$u:$p" | chpasswd
    echo "Created $u"
  fi

}
for g in users backup; do
  if ! getent group "$g" >/dev/null; then
    groupadd "$g"
    echo "Created group $g"
  fi
done

add_users_if_missing "$ADMIN_USER" "$ADMIN_PASS"
usermod -aG sudo,users "$ADMIN_USER"

add_users_if_missing "$USER_REGULAR" "$USER_REGULAR_PASS"
usermod -aG users "$USER_REGULAR"

add_users_if_missing "$BACKUP_USER" "$BACKUP_PASS"
usermod -aG backup "$BACKUP_USER"

echo "Pouzivatelia a skupiny konfigurovane"
