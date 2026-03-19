#!/bin/bash

# Automatická aktualizácia systému

if [ "$EUID" -ne 0 ]; then
  echo "Prosím, spusťte skript ako root (sudo)."
  exit 1
fi

echo "[INFO] Začínam aktualizáciu systému..."
apt update -q
apt upgrade -y
apt autoremove -y

echo "[OK] Systém je aktuálny. (Čas: $(date))" >>/var/log/update_script.log
echo "[OK] Aktualizácia dokončená."
