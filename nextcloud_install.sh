#!/bin/bash

set -e

# --- Configuration ---
NC_DB="nextcloud"
NC_DB_USER="ncuser"
NC_DB_PASS="SilnaDatabaza123"
NC_ADMIN="ncadmin"
NC_ADMIN_PASS="Ncadminpass123"
WWW_DIR="/var/www/nextcloud"

# Remote database server IP (VM-to-VM internal network)
DB_HOST="192.168.100.2"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# --- Pre-flight: check DB is reachable before doing anything ---
echo "[CHECK] Testing connection to database server at $DB_HOST:3306..."
if ! nc -z -w5 "$DB_HOST" 3306 2>/dev/null; then
  echo "[ERROR] Cannot reach MariaDB at $DB_HOST:3306"
  echo "        Make sure the Database VM is running and db_maria_install.sh has been run first."
  exit 1
fi
echo "[CHECK] Database server is reachable."

# ----------------------------------------------------------------

echo "[1/5] Installing web server and PHP..."
apt update -q

# No mariadb-server here — DB lives on a separate VM
# php-mysql provides the client libraries Nextcloud needs to talk to remote DB
apt install -y \
  apache2 \
  libapache2-mod-php \
  php-gd php-xml php-mbstring php-curl php-zip \
  php-intl php-readline php-cli php-mysql \
  php-apcu php-redis php-bcmath php-gmp php-imagick \
  netcat-openbsd unzip curl

echo "[2/5] Optimizing PHP settings..."
PHPINI="/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/apache2/php.ini"

if [ -f "$PHPINI" ]; then
  sed -i "s/memory_limit = .*/memory_limit = 512M/" "$PHPINI"
  sed -i "s/upload_max_filesize = .*/upload_max_filesize = 2G/" "$PHPINI"
  sed -i "s/post_max_size = .*/post_max_size = 2G/" "$PHPINI"
  sed -i "s/max_execution_time = .*/max_execution_time = 360/" "$PHPINI"
  sed -i "s/;date.timezone =.*/date.timezone = Europe\/Bratislava/" "$PHPINI"
  echo "[INFO] PHP config written to $PHPINI"
else
  echo "[WARN] php.ini not found at $PHPINI — skipping PHP tuning"
fi

echo "[3/5] Downloading and extracting Nextcloud..."
mkdir -p /tmp/nc_install
cd /tmp/nc_install

curl -o nextcloud.zip -L "https://download.nextcloud.com/server/releases/latest.zip"
unzip -q nextcloud.zip
rm -rf "$WWW_DIR"
mv nextcloud "$WWW_DIR"
chown -R www-data:www-data "$WWW_DIR"
chmod -R 750 "$WWW_DIR"

echo "[4/5] Configuring Apache..."
cat >/etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost *:80>
    DocumentRoot ${WWW_DIR}

    <Directory ${WWW_DIR}/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOF

a2enmod rewrite headers env dir mime setenvif
a2ensite nextcloud.conf
a2dissite 000-default.conf
systemctl reload apache2

echo "[5/5] Running Nextcloud installer (occ)..."
sudo -u www-data php "$WWW_DIR/occ" maintenance:install \
  --database "mysql" \
  --database-host "$DB_HOST" \
  --database-name "$NC_DB" \
  --database-user "$NC_DB_USER" \
  --database-pass "$NC_DB_PASS" \
  --admin-user "$NC_ADMIN" \
  --admin-pass "$NC_ADMIN_PASS"

# Allow access from the host via localhost port forward (10.0.2.15 + loopback)
echo "[INFO] Adding trusted domains..."
sudo -u www-data php "$WWW_DIR/occ" config:system:set trusted_domains 0 --value="localhost"
sudo -u www-data php "$WWW_DIR/occ" config:system:set trusted_domains 1 --value="10.0.2.15"
sudo -u www-data php "$WWW_DIR/occ" config:system:set trusted_domains 2 --value="192.168.100.1"

# Point Nextcloud at the remote DB host explicitly in config
sudo -u www-data php "$WWW_DIR/occ" config:system:set dbhost --value="$DB_HOST"

echo ""
echo "============================================"
echo "[OK] Nextcloud installed successfully!"
echo "  Admin user: $NC_ADMIN"
echo "  Database:   $NC_DB on $DB_HOST"
echo "  Access at:  http://localhost:8080  (from your Arch host)"
echo "============================================"
