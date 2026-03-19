#!/bin/bash

# Firewall konfigurácia pre Database Server

NC_SERVER_IP="192.168.100.1" # Nextcloud VM on internal network
SSH_PORT=22

if [ "$EUID" -ne 0 ]; then
  echo "Prosím, spusťte skript ako root (sudo)."
  exit 1
fi

echo "[1/3] Inštalujem UFW..."
apt update -q
apt install -y ufw

echo "[2/3] Nastavujem pravidlá firewallu..."
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# SSH — only from host NAT network
ufw allow "$SSH_PORT"/tcp

# MariaDB — only from Nextcloud VM on internal network
ufw allow from "$NC_SERVER_IP" to any port 3306 proto tcp

# Loopback
ufw allow in on lo
ufw allow out on lo

echo "[3/3] Zapínam firewall..."
ufw --force enable

echo ""
echo "============================================"
echo "[OK] Firewall aktívny"
echo "  SSH:     povolené (port 22)"
echo "  MariaDB: povolené iba z $NC_SERVER_IP"
echo "  Ostatné: blokované"
echo "============================================"
ufw status verbose
