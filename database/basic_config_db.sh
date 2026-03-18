#!/bin/bash

# Nastavenie základných parametrov pre Database Server (Debian)

if [ "$EUID" -ne 0 ]; then
  echo "Prosím, spusťte skript ako root (sudo)."
  exit 1
fi

echo "=== KONFIGURÁCIA DATABÁZOVÉHO SERVERA ==="

# --- Configuration ---
DB_HOSTNAME="db-server"
TIMEZONE="Europe/Bratislava"

# ens3 — NAT interface (internet + SSH from host)
NAT_IP="10.0.2.16"
NAT_NETMASK="255.255.255.0"
NAT_GW="10.0.2.2"
NAT_DNS="8.8.8.8"

# ens4 — internal VM-to-VM network
INTERNAL_IP="192.168.100.2"
INTERNAL_NETMASK="255.255.255.0"

# Auto-detect NICs
NAT_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | sed -n '1p')
INTERNAL_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | sed -n '2p')

echo "[INFO] NAT interface:      $NAT_IFACE"
echo "[INFO] Internal interface: ${INTERNAL_IFACE:-not detected}"

# --- 1. Hostname ---
echo "[1/4] Nastavujem hostname na '$DB_HOSTNAME'..."
hostnamectl set-hostname "$DB_HOSTNAME"
sed -i "/127.0.1.1/d" /etc/hosts
echo "127.0.1.1 $DB_HOSTNAME" >>/etc/hosts

# --- 2. Timezone ---
echo "[2/4] Nastavujem časovú zónu $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"

# --- 3. Network ---
echo "[3/4] Konfigurujem sieťové rozhrania..."

if [ -n "$INTERNAL_IFACE" ]; then
  cat >/etc/network/interfaces <<EOF
# Základná konfigurácia vytvorená skriptom
auto lo
iface lo inet loopback

# NAT interface — internet + SSH from host
auto $NAT_IFACE
iface $NAT_IFACE inet static
    address $NAT_IP
    netmask $NAT_NETMASK
    gateway $NAT_GW
    dns-nameservers $NAT_DNS

# Internal VM-to-VM network
auto $INTERNAL_IFACE
iface $INTERNAL_IFACE inet static
    address $INTERNAL_IP
    netmask $INTERNAL_NETMASK
EOF
else
  echo "[WARN] Second NIC not detected — using ens4 as placeholder"
  cat >/etc/network/interfaces <<EOF
# Základná konfigurácia vytvorená skriptom
auto lo
iface lo inet loopback

# NAT interface — internet + SSH from host
auto $NAT_IFACE
iface $NAT_IFACE inet static
    address $NAT_IP
    netmask $NAT_NETMASK
    gateway $NAT_GW
    dns-nameservers $NAT_DNS

# Internal VM-to-VM network (placeholder)
auto ens4
iface ens4 inet static
    address $INTERNAL_IP
    netmask $INTERNAL_NETMASK
EOF
fi

echo "[INFO] Reštartujem sieťové služby..."
systemctl restart networking

# --- 4. Time sync ---
echo "[4/4] Inštalujem chrony pre synchronizáciu času..."
apt install -y chrony
systemctl enable chrony
systemctl restart chrony

echo "----------------------------------------"
echo "KONFIGURÁCIA JE HOTOVÁ:"
echo "  Hostname:    $(hostname)"
echo "  NAT IP:      $NAT_IP (via $NAT_IFACE)"
echo "  Internal IP: $INTERNAL_IP (via ${INTERNAL_IFACE:-ens4})"
echo "  Timezone:    $TIMEZONE"
echo "  Čas:         $(date)"
echo "----------------------------------------"
echo "[INFO] Odporúča sa reštartovať server."
