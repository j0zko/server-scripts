#!/bin/bash

# --- Configuration ---
HOSTNAME="cloud"
TIMEZONE="Europe/Bratislava"
IP_ADRESS="10.0.2.15"
DNS="8.8.8.8, 8.8.4.4"
GATEWAY="10.0.2.2"
NETPLAN_FILE="/etc/netplan/01-cloud-config.yaml"

# Corrected variable assignment (no spaces around '=')
INTERFACE=$(ip route | awk '/default/ {print $5}')

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

echo "[INFO] Starting cloud server basic config"

echo "Setting Hostname...."
hostnamectl set-hostname "$HOSTNAME"

echo "Setting timezone..."
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

# Update /etc/hosts
sed -i "/127.0.1.1/d" /etc/hosts
echo "127.0.1.1 $HOSTNAME" >>/etc/hosts

echo "[INFO] Configuring static IP using netplan"

# Writing the YAML file with correct 2-space indentation
cat <<EOF >"$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP_ADRESS/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS]
EOF

# Set permissions and apply network config
chmod 600 "$NETPLAN_FILE"
netplan apply

echo "[INFO] Installing base packages"
apt update
# Fixed: removed the stray hyphen before package names
apt install -y sudo curl wget vim net-tools chrony

# Ensure time syncing is active
systemctl enable chrony
systemctl restart chrony

echo "[OK] Cloud server basic config done"
echo "[INFO] Reboot is recommended to ensure all changes (like hostname) take full effect."
