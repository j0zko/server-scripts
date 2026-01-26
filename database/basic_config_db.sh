#!/bin/bash
# Nastavenie základných parametrov pre Database Server (Debian)

# Kontrola, či je skript spustený ako root
if [ "$EUID" -ne 0 ]; then
  echo "Prosím, spusťte skript ako root (sudo)."
  exit
fi

echo "=== KONFIGURÁCIA DATABÁZOVÉHO SERVERA ==="

# 1. Nastavenie Hostname
DB_HOSTNAME="db-server"
echo "[INFO] Nastavujem Hostname na: $DB_HOSTNAME"
hostnamectl set-hostname "$DB_HOSTNAME"

# 2. Nastavenie Času a Dátumu
echo "[INFO] Nastavujem časovú zónu Europe/Bratislava a NTP..."
timedatectl set-timezone Europe/Bratislava
timedatectl set-ntp true

# 3. Nastavenie IP Adresy (Statická IP pre sieť 10.0.2.x)
# Automaticky zistíme názov sieťového rozhrania (napr. enp0s3)
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)
IP_ADDR="10.0.2.16"
NETMASK="255.255.255.0"
GATEWAY="10.0.2.2"
DNS="8.8.8.8"

echo "[INFO] Konfigurujem rozhranie $INTERFACE na IP $IP_ADDR..."

cat <<EOF >/etc/network/interfaces
# Základná konfigurácia vytvorená skriptom
auto lo
iface lo inet loopback

# Statická IP pre komunikáciu s Cloud Serverom
auto $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDR
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS
EOF

# 4. Aplikácia zmien
echo "[INFO] Reštartujem sieťové služby..."
systemctl restart networking

echo "----------------------------------------"
echo "KONFIGURÁCIA JE HOTOVÁ:"
echo "Hostname: $(hostname)"
echo "IP Adresa: $(hostname -I | awk '{print $1}')"
echo "Aktuálny čas: $(date)"
echo "----------------------------------------"
