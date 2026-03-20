#!/bin/bash

# ============================================================
#  prezentacia.sh — Prehľad konfigurácie serverov
#  Autor: j0zko
#  Projekt: Úložisko dát — Linux
# ============================================================

GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

divider() {
  echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
}

header() {
  echo ""
  divider
  echo -e "  ${BOLD}${CYAN}$1${NC}"
  divider
}

ok() { echo -e "  ${GREEN}[✓]${NC} $1"; }
info() { echo -e "  ${YELLOW}[i]${NC} $1"; }
val() { echo -e "      ${BOLD}$1:${NC} $2"; }

clear
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║         PROJEKT: ÚLOŽISKO DÁT                ║"
echo "  ║         Linux — Téma č.4                     ║"
echo "  ║         Prezentácia konfigurácie              ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo -e "${NC}"
sleep 1

# --- 1. SYSTEM INFO ---
header "1. ZÁKLADNÉ INFORMÁCIE O SERVERI"
val "Hostname" "$(hostname)"
val "OS" "$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
val "Kernel" "$(uname -r)"
val "IP Adresa" "$(hostname -I | awk '{print $1}')"
val "Čas" "$(date '+%Y-%m-%d %H:%M:%S')"
val "Uptime" "$(uptime -p)"
val "Disk" "$(df -h / | tail -1 | awk '{print $3 " / " $2 " (" $5 " použité)"}')"
sleep 1

# --- 2. USERS AND GROUPS ---
header "2. UŽÍVATELIA A SKUPINY"
ok "Vytvorení užívatelia:"
for u in sysadmin student backupuser; do
  if id "$u" &>/dev/null; then
    groups=$(id -Gn "$u" | tr ' ' ',')
    echo -e "      ${GREEN}✓${NC} $u  →  skupiny: $groups"
  else
    echo -e "      ${RED}✗${NC} $u  →  nenájdený"
  fi
done
sleep 1

# --- 3. SERVICES ---
header "3. BEŽIACE SLUŽBY"
services=("apache2" "mariadb" "ufw" "smbd" "chrony" "ssh")
for s in "${services[@]}"; do
  status=$(systemctl is-active "$s" 2>/dev/null)
  if [ "$status" = "active" ]; then
    ok "$s  →  ${GREEN}AKTÍVNY${NC}"
  else
    echo -e "  ${RED}[✗]${NC} $s  →  ${RED}NEAKTÍVNY${NC}"
  fi
done
sleep 1

# --- 4. FIREWALL ---
header "4. FIREWALL (UFW)"
if command -v ufw &>/dev/null; then
  ufw_status=$(ufw status | head -1)
  ok "UFW stav: $ufw_status"
  echo ""
  ufw status | grep -v "^Status" | grep -v "^$" | while read line; do
    echo "      $line"
  done
else
  info "UFW nie je nainštalovaný"
fi
sleep 1

# --- 5. NEXTCLOUD ---
header "5. NEXTCLOUD"
if [ -f "/var/www/nextcloud/occ" ]; then
  ok "Nextcloud je nainštalovaný v /var/www/nextcloud"
  nc_version=$(sudo -u www-data php /var/www/nextcloud/occ status 2>/dev/null | grep "version:" | awk '{print $3}')
  val "Verzia" "$nc_version"
  val "Webový prístup" "http://$(hostname -I | awk '{print $1}')/  alebo  http://192.168.0.180:8080"
  ok "Trusted domains:"
  sudo -u www-data php /var/www/nextcloud/occ config:system:get trusted_domains 2>/dev/null | while read domain; do
    echo "      → $domain"
  done
else
  info "Nextcloud nie je nainštalovaný"
fi
sleep 1

# --- 6. DATABASE ---
header "6. DATABÁZA (MariaDB)"
if systemctl is-active mariadb &>/dev/null; then
  ok "MariaDB beží"
  val "Bind address" "$(grep bind-address /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null | awk '{print $3}')"
  ok "Databázy:"
  mysql -u root -e "SHOW DATABASES;" 2>/dev/null | grep -v "Database\|information_schema\|performance_schema\|sys" | while read db; do
    echo "      → $db"
  done
  ok "DB užívatelia pre Nextcloud:"
  mysql -u root -e "SELECT user, host FROM mysql.user WHERE user='ncuser';" 2>/dev/null | grep -v "user" | while read line; do
    echo "      → $line"
  done
else
  info "MariaDB nebeží na tomto serveri (je na DB VM)"
fi
sleep 1

# --- 7. SAMBA ---
header "7. SAMBA ZDIEĽANIE"
if command -v smbclient &>/dev/null || systemctl is-active smbd &>/dev/null; then
  ok "Samba je nainštalovaná"
  if grep -q "\[cloud_backup\]" /etc/samba/smb.conf 2>/dev/null; then
    ok "Zdieľaný priečinok: cloud_backup"
    val "Cesta" "/srv/cloud_data"
    val "Prístup" "Iba skupina 'backup'"
    val "Windows prístup" "\\\\192.168.0.180\\cloud_backup"
  fi
else
  info "Samba nie je nainštalovaná"
fi
sleep 1

# --- 8. PERMISSIONS ---
header "8. OPRÁVNENIA A ACL (/srv/cloud_data)"
if [ -d "/srv/cloud_data" ]; then
  ok "Priečinok existuje"
  val "Vlastník" "$(stat -c '%U:%G' /srv/cloud_data)"
  val "Práva" "$(stat -c '%a' /srv/cloud_data)"
  ok "ACL nastavenia:"
  getfacl /srv/cloud_data 2>/dev/null | grep -v "^#\|^$" | while read line; do
    echo "      $line"
  done
else
  info "/srv/cloud_data neexistuje"
fi
sleep 1

# --- 9. BACKUPS ---
header "9. ZÁLOHOVANIE"
BACKUP_DIR="/var/backups/project"
if [ -d "$BACKUP_DIR" ]; then
  count=$(find "$BACKUP_DIR" -name "*.tar.gz" | wc -l)
  ok "Zálohy sa nachádzajú v $BACKUP_DIR"
  val "Počet záloh" "$count"
  val "Retenčná politika" "7 dní"
  ok "Posledné zálohy:"
  ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -3 | while read line; do
    echo "      $line"
  done
else
  info "Zálohy ešte neboli vytvorené"
fi
sleep 1

# --- 10. SCRIPTS ---
header "10. SKRIPTY PROJEKTU"
SCRIPT_DIR="/home/cloud/server-scripts"
if [ -d "$SCRIPT_DIR" ]; then
  ok "Skripty v $SCRIPT_DIR:"
  ls "$SCRIPT_DIR"/*.sh 2>/dev/null | while read s; do
    echo "      → $(basename $s)"
  done
else
  ok "Skripty v $(pwd):"
  ls *.sh 2>/dev/null | while read s; do
    echo "      → $s"
  done
fi
sleep 1

# --- SUMMARY ---
echo ""
divider
echo -e "  ${BOLD}${GREEN}PROJEKT ÚSPEŠNE NAKONFIGUROVANÝ${NC}"
divider
echo -e "  ${CYAN}Cloud server:${NC}    http://192.168.0.180:8080"
echo -e "  ${CYAN}Dashboard:${NC}       http://192.168.0.180:8080/dashboard"
echo -e "  ${CYAN}DB dashboard:${NC}    http://192.168.0.180:8081/dashboard"
echo -e "  ${CYAN}Samba:${NC}           \\\\\\\\192.168.0.180\\\\cloud_backup"
echo ""
echo -e "  Vytvorené automatizovanými bash skriptami."
echo ""
divider
echo ""
