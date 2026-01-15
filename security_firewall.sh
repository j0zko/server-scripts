#!/bin/bash

# --- Configuration ---
DB_SERVER_IP="192.168.56.11"
SSH_PORT=22 # Fixed: No spaces around '='

set -e

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "[1/3] Installing UFW..."
apt update
apt install -y ufw

echo "[2/3] Resetting UFW and applying rules..."
# --force reset ensures we start from a clean slate
ufw --force reset

# 1. Default Policies
# Block everything coming in, allow everything going out
ufw default deny incoming
ufw default allow outgoing

# 2. Essential Services
ufw allow "$SSH_PORT"/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# 3. Database Access
# Note: This allows the DB server to connect TO this server on 3306.
ufw allow from "$DB_SERVER_IP" to any port 3306 proto tcp

# 4. Loopback (Required for many local system services)
ufw allow in on lo
ufw allow out on lo

echo "[3/3] Enabling Firewall..."
ufw --force enable

echo "-------------------------------------------------------"
echo "[OK] UFW is active. Current Rules:"
ufw status verbose
echo "-------------------------------------------------------"
