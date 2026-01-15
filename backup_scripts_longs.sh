#!/bin/bash
set -e

# --- Configuration ---
BACKUP_DIR="/var/backups/project"
REMOTE_USER="backupuser"
REMOTE_HOST="192.168.56.11"
REMOTE_DIR="/remote/backups/project"
RETENTION=7

# Check for root (needed to read /root/scripts and /var/log)
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root to access /var/log and /root."
  exit 1
fi

echo "[1/4] Preparing local environment..."
mkdir -p "$BACKUP_DIR"
ts=$(date +"%Y%m%d-%H%M")
FILE_NAME="scripts-logs-$ts.tar.gz"

echo "[2/4] Creating the archive..."
# 'p' preserves permissions. We redirect errors because /var/log often has
# files that change during the backup process, which causes tar to exit with code 1.
tar -czpf "$BACKUP_DIR/$FILE_NAME" /root/scripts /var/www /var/log 2>/dev/null || true

echo "[3/4] Cleaning up local backups older than $RETENTION days..."
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$RETENTION -delete

echo "[4/4] Processing remote sync..."
if [ "$1" == "--push" ]; then
  echo "Pushing backups to ${REMOTE_HOST}..."
  # 'a' is archive mode, 'v' is verbose, 'z' is compress, 'e' specifies ssh
  # We use --delete to make the remote side match the local side (deleting old backups there too)
  rsync -avz --delete "$BACKUP_DIR/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
else
  echo "Skipping remote push (use --push flag to enable)."
fi

echo "[OK] Backup process finished successfully."
echo "Location: $BACKUP_DIR/$FILE_NAME"
