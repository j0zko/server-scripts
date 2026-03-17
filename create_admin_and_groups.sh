#!/bin/bash

# --- Configuration ---
ADMIN_USER="sysadmin"
ADMIN_PASS="Admin@Secure123!"
USER_REGULAR="student"
USER_REGULAR_PASS="Student@Secure123!"
BACKUP_USER="backupuser"
BACKUP_PASS="Backup@Secure123!"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

set -e

add_user_if_missing() {
  local u=$1
  local p=$2
  if id "$u" >/dev/null 2>&1; then
    echo "[INFO] User '$u' already exists — skipping"
  else
    useradd -m -s /bin/bash "$u"
    echo "$u:$p" | chpasswd
    echo "[OK] Created user '$u'"
  fi
}

# --- Create groups ---
for g in users backup; do
  if ! getent group "$g" >/dev/null; then
    groupadd "$g"
    echo "[OK] Created group '$g'"
  else
    echo "[INFO] Group '$g' already exists — skipping"
  fi
done

# --- Create users and assign groups ---
add_user_if_missing "$ADMIN_USER" "$ADMIN_PASS"
usermod -aG sudo,users "$ADMIN_USER"

add_user_if_missing "$USER_REGULAR" "$USER_REGULAR_PASS"
usermod -aG users "$USER_REGULAR"

add_user_if_missing "$BACKUP_USER" "$BACKUP_PASS"
usermod -aG backup "$BACKUP_USER"

# --- Summary ---
echo ""
echo "============================================"
echo "[OK] Users and groups configured"
echo "  $ADMIN_USER  → groups: sudo, users"
echo "  $USER_REGULAR → groups: users"
echo "  $BACKUP_USER  → groups: backup"
echo "============================================"
