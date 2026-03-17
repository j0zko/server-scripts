#!/bin/bash

# --- Configuration ---
HOSTNAME="cloud"
TIMEZONE="Europe/Bratislava"

# First NIC — QEMU NAT (internet access)
IP_ADDRESS="10.0.2.15"
GATEWAY="10.0.2.2"
DNS="8.8.8.8,8.8.4.4" # No spaces — netplan is strict about this

# Second NIC — VM-to-VM internal network
INTERNAL_IP="192.168.100.1" # Nextcloud side of the internal link
INTERNAL_PREFIX="24"

NETPLAN_FILE="/etc/netplan/01-cloud-config.yaml"

# Auto-detect NICs
# First NIC = the one with the default route (NAT interface)
NAT_IFACE=$(ip route | awk '/default/ {print $5}')
# Second NIC = any other ethernet interface that isn't lo or the NAT one
INTERNAL_IFACE=$(ip link show | awk -F': ' '/^[0-9]+:/{print $2}' |
  grep -v lo | grep -v "$NAT_IFACE" | head -1)

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "[INFO] Starting cloud server basic config"
echo "  NAT interface:      $NAT_IFACE"
echo "  Internal interface: ${INTERNAL_IFACE:-not found yet}"

# --- Hostname ---
echo "[1/5] Setting hostname to '$HOSTNAME'..."
hostnamectl set-hostname "$HOSTNAME"
sed -i "/127.0.1.1/d" /etc/hosts
echo "127.0.1.1 $HOSTNAME" >>/etc/hosts

# --- Timezone ---
echo "[2/5] Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

# --- Netplan ---
echo "[3/5] Writing netplan config..."

# Remove any existing netplan files to avoid conflicts
rm -f /etc/netplan/*.yaml

if [ -n "$INTERNAL_IFACE" ]; then
  # Two NICs detected — configure both
  cat <<EOF >"$NETPLAN_FILE"
network:
  version: 2
  ethernets:
    $NAT_IFACE:
      dhcp4: no
      addresses:
        - $IP_ADDRESS/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS]
    $INTERNAL_IFACE:
      dhcp4: no
      addresses:
        - $INTERNAL_IP/$INTERNAL_PREFIX
EOF
else
  # Only one NIC found — internal NIC may appear after DB VM starts
  # We still write it here as a placeholder using ens4 (QEMU's usual name)
  echo "[WARN] Second NIC not detected yet — using 'ens4' as placeholder."
  echo "[WARN] If VM-to-VM comms fail, re-run this script after both VMs are running."
  cat <<EOF >"$NETPLAN_FILE"
network:
  version: 2
  ethernets:
    $NAT_IFACE:
      dhcp4: no
      addresses:
        - $IP_ADDRESS/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS]
    ens4:
      dhcp4: no
      addresses:
        - $INTERNAL_IP/$INTERNAL_PREFIX
EOF
fi

chmod 600 "$NETPLAN_FILE"

echo "[INFO] Applying netplan..."
netplan apply
if [ $? -ne 0 ]; then
  echo "[ERROR] netplan apply failed — check $NETPLAN_FILE"
  exit 1
fi

# --- Base packages ---
echo "[4/5] Installing base packages..."
apt update -q
apt install -y sudo curl wget vim net-tools chrony

# --- Time sync ---
echo "[5/5] Enabling time sync..."
systemctl enable chrony
systemctl restart chrony

# --- Summary ---
echo ""
echo "============================================"
echo "[OK] Cloud server basic config complete"
echo "  Hostname:    $HOSTNAME"
echo "  Timezone:    $TIMEZONE"
echo "  NAT IP:      $IP_ADDRESS (via $NAT_IFACE)"
echo "  Internal IP: $INTERNAL_IP (via ${INTERNAL_IFACE:-ens4})"
echo "  Gateway:     $GATEWAY"
echo "  DNS:         $DNS"
echo "============================================"
echo "[INFO] Reboot recommended to apply all changes."
