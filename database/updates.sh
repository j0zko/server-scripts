#!/bin/bash
# Automatická aktualizácia systému

echo "[INFO] Začínam aktualizáciu systému..."
apt update
apt upgrade -y
apt autoremove -y

echo "[OK] Systém je aktuálny. (Čas: $(date))" >>/var/log/update_script.log
