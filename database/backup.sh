#!/bin/bash
# Zálohuje skripty a logy do archívu

BACKUP_DIR="/var/backups/server_logs"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%F_%H-%M)

# Záloha logov a domovského priečinka so skriptami
tar -czf "$BACKUP_DIR/backup_$TIMESTAMP.tar.gz" /var/log /home/sysadmin /opt

# Vymazanie záloh starších ako 7 dní
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete

echo "[OK] Záloha vytvorená: $BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
