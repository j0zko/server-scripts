#!/bin/bash

# Zálohuje skripty, logy a konfiguráciu databázy

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Prosím, spusťte skript ako root (sudo)."
  exit 1
fi

BACKUP_DIR="/var/backups/server_logs"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%F_%H-%M)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

echo "[INFO] Vytváram zálohu..."

# Backup logs, sysadmin home, MariaDB config
tar -czpf "$BACKUP_FILE" \
  /var/log \
  /home/sysadmin \
  /etc/mysql \
  2>/dev/null || true

if [ -f "$BACKUP_FILE" ]; then
  echo "[OK] Záloha vytvorená: $BACKUP_FILE"
  echo "     Veľkosť: $(du -sh "$BACKUP_FILE" | cut -f1)"
else
  echo "[ERROR] Záloha zlyhala!"
  exit 1
fi

# Vymazanie záloh starších ako 7 dní
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete
echo "[OK] Staré zálohy vyčistené."
