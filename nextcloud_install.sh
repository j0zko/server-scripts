#!/bin/bash
set -e

# --- Configuration ---
NC_DB="nextcloud"
NC_DB_USER="ncuser"
NC_DB_PASS="Strongpass123!" # Use a strong password
NC_ADMIN="ncadmin"
NC_ADMIN_PASS="Ncadminpass123!"
WWW_DIR="/var/www/nextcloud"
NEXTCLOUD_VERSION="latest" # Downloads the newest stable version

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "[1/5] Installing Web Server, Database, and PHP..."
apt update
# Added mariadb-server and missing php modules (bcmath, gmp, imagick)
apt install -y apache2 mariadb-server libapache2-mod-php php-gd php-xml \
  php-mbstring php-curl php-zip php-intl php-readline php-cli php-mysql \
  php-apcu php-redis php-bcmath php-gmp php-imagick unzip curl

echo "[2/5] Configuring MariaDB..."
# Ensure MariaDB is running
systemctl start mariadb
mysql -e "CREATE DATABASE IF NOT EXISTS ${NC_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${NC_DB_USER}'@'localhost' IDENTIFIED BY '${NC_DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${NC_DB}.* TO '${NC_DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "[3/5] Optimizing PHP settings..."
PHPINI="/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/apache2/php.ini"
if [ -f "$PHPINI" ]; then
  sed -i "s/memory_limit = .*/memory_limit = 512M/" "$PHPINI"
  sed -i "s/upload_max_filesize = .*/upload_max_filesize = 2G/" "$PHPINI"
  sed -i "s/post_max_size = .*/post_max_size = 2G/" "$PHPINI"
  sed -i "s/max_execution_time = .*/max_execution_time = 360/" "$PHPINI"
  sed -i "s/;date.timezone =.*/date.timezone = Europe\/Bratislava/" "$PHPINI"
fi

echo "[4/5] Downloading and Extracting Nextcloud..."
mkdir -p /tmp/nc_install
cd /tmp/nc_install
# Using 'latest.zip' is safer for automation
curl -o nextcloud.zip -L "https://download.nextcloud.com/server/releases/latest.zip"
unzip -q nextcloud.zip
rm -rf "$WWW_DIR"
mv nextcloud "$WWW_DIR"
chown -R www-data:www-data "$WWW_DIR"
chmod -R 750 "$WWW_DIR"

echo "[5/5] Configuring Apache..."
cat >/etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost *:80>
    DocumentRoot ${WWW_DIR}
    <Directory ${WWW_DIR}/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
    </Directory>
</VirtualHost>
EOF

a2enmod rewrite headers env dir mime setenvif
a2ensite nextcloud.conf
a2dissite 000-default.conf
systemctl reload apache2

# Optional: Automated Installation (skips the web setup wizard)
echo "[INFO] Running internal Nextcloud setup..."
sudo -u www-data php "$WWW_DIR/occ" maintenance:install \
  --database "mysql" --database-name "$NC_DB" \
  --database-user "$NC_DB_USER" --database-pass "$NC_DB_PASS" \
  --admin-user "$NC_ADMIN" --admin-pass "$NC_ADMIN_PASS"

echo "[OK] Nextcloud is installed!"
echo "Visit your server IP to login as: $NC_ADMIN"
