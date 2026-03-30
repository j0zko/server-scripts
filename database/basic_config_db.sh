#!/bin/bash
# Nastavenie základných parametrov pre Database Server (Debian) - Netplan version

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
NAT_GW="10.0.2.2"
NAT_DNS="8.8.8.8,1.1.1.1" # netplan format (comma separated, no spaces)

# ens4 — internal VM-to-VM network
INTERNAL_IP="192.168.100.2"
INTERNAL_PREFIX="24"

NETPLAN_FILE="/etc/netplan/01-db-config.yaml"

# Auto-detect NICs
# NAT_IFACE = interface with default route (most reliable)
NAT_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)

# INTERNAL_IFACE = any other ethernet interface
INTERNAL_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | grep -v "$NAT_IFACE" | head -n1)

echo "[INFO] NAT interface: ${NAT_IFACE:-ens3}"
echo "[INFO] Internal interface: ${INTERNAL_IFACE:-not detected yet}"

# --- 1. Hostname ---
echo "[1/4] Nastavujem hostname na '$DB_HOSTNAME'..."
hostnamectl set-hostname "$DB_HOSTNAME"
sed -i "/127.0.1.1/d" /etc/hosts
echo "127.0.1.1 $DB_HOSTNAME" >>/etc/hosts

# --- 2. Timezone ---
echo "[2/4] Nastavujem časovú zónu $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"

# --- 3. Network (Netplan) ---
echo "[3/4] Konfigurujem sieťové rozhrania (netplan)..."

# Remove old interfaces config to avoid conflicts
rm -f /etc/network/interfaces /etc/network/interfaces.d/*

# Create netplan config
cat >"$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    ${NAT_IFACE:-ens3}:
      dhcp4: no
      addresses: [$NAT_IP/24]
      routes:
        - to: default
          via: $NAT_GW
      nameservers:
        addresses: [$NAT_DNS]

    ${INTERNAL_IFACE:-ens4}:
      dhcp4: no
      addresses: [$INTERNAL_IP/$INTERNAL_PREFIX]
EOF

chmod 600 "$NETPLAN_FILE"

echo "[INFO] Applying netplan configuration..."
netplan apply

if [ $? -ne 0 ]; then
  echo "[WARN] netplan apply failed. Check the config with: netplan --debug apply"
fi

# --- 4. Time sync ---
echo "[4/4] Inštalujem chrony pre synchronizáciu času..."
apt update -qq
apt install -y chrony
systemctl enable --now chrony
systemctl restart chrony

# --- Summary ---
echo "----------------------------------------"
echo "KONFIGURÁCIA JE HOTOVÁ:"
echo " Hostname: $(hostname)"
echo " NAT IP: $NAT_IP (via ${NAT_IFACE:-ens3})"
echo " Internal IP: $INTERNAL_IP (via ${INTERNAL_IFACE:-ens4})"
echo " Timezone: $TIMEZONE"
echo " Čas: $(date)"
echo "----------------------------------------"
echo "[INFO] Odporúča sa reštartovať server po spustení druhej VM."
