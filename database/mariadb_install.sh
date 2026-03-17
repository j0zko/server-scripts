#!/bin/bash

set -e

# --- Configuration --- must match nextcloud_install.sh ---
NC_SERVER_IP="192.168.100.1" # Nextcloud VM on internal network
INTERNAL_IP="192.168.100.2"  # This DB server on internal network

DB_NAME="nextcloud"
DB_USER="ncuser"
DB_PASS="SilnaDatabaza123"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# --- Configure internal NIC (ens4) ---
echo "[1/4] Configuring internal network interface (ens4)..."
cat >>/etc/network/interfaces <<EOF

# Internal VM-to-VM network
auto ens4
iface ens4 inet static
    address $INTERNAL_IP
    netmask 255.255.255.0
EOF

ip link set ens4 up
ip addr add "$INTERNAL_IP/24" dev ens4 2>/dev/null || true
echo "[INFO] ens4 set to $INTERNAL_IP"

# --- Install MariaDB ---
echo "[2/4] Installing MariaDB..."
apt update -q
apt install -y mariadb-server netcat-openbsd

# --- Allow remote connections ---
echo "[3/4] Configuring MariaDB to accept remote connections..."
sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' \
  /etc/mysql/mariadb.conf.d/50-server.cnf

systemctl enable mariadb
systemctl restart mariadb

# --- Create DB and user ---
echo "[4/4] Creating database and user for Nextcloud..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME}
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_general_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'${NC_SERVER_IP}'
    IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON ${DB_NAME}.*
    TO '${DB_USER}'@'${NC_SERVER_IP}';

FLUSH PRIVILEGES;
EOF

# --- Verify ---
echo "[CHECK] Testing that DB user was created correctly..."
mysql -u root -e "SELECT user, host FROM mysql.user WHERE user='${DB_USER}';"

echo ""
echo "============================================"
echo "[OK] MariaDB is ready for Nextcloud"
echo "  Database:    $DB_NAME"
echo "  User:        $DB_USER@$NC_SERVER_IP"
echo "  Listening:   0.0.0.0:3306"
echo "  Internal IP: $INTERNAL_IP (ens4)"
echo "============================================"
echo "[INFO] Run nextcloud_install.sh on the Nextcloud VM next."
