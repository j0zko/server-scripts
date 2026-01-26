#!/bin/bash
echo "[INFO] Inštalujem MariaDB..."
apt update && apt install -y mariadb-server

# Povolenie prístupu z Cloud Servera (10.0.2.15)
sed -i 's/127.0.0.1/0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

systemctl restart mariadb

# Vytvorenie DB a užívateľa pre Cloud
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS cloud_db;
CREATE USER IF NOT EXISTS 'cloud_admin'@'10.0.2.15' IDENTIFIED BY 'DbHeslo123';
GRANT ALL PRIVILEGES ON cloud_db.* TO 'cloud_admin'@'10.0.2.15';
FLUSH PRIVILEGES;
EOF

echo "[OK] Databáza beží."
