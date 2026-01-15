#!/bin/bash

# 1. Check if the user provided a hostname argument
if [ -z "$1" ]; then
  echo "Usage: $0 <new-hostname>"
  exit 1
fi

# 2. Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

NEW_HOSTNAME=$1

echo "[INFO] Setting hostname to $NEW_HOSTNAME"

# 3. Update the system hostname
hostnamectl set-hostname "$NEW_HOSTNAME"

# 4. Update /etc/hosts
# We target the 127.0.1.1 line specifically used for the system's own hostname

sed -i "/127.0.1.1/d" /etc/hosts
echo "127.0.1.1 $NEW_HOSTNAME" >>/etc/hosts

echo "[OK] Hostname set successfully to $NEW_HOSTNAME"
echo "Re-login or reboot recommended to see the change in your prompt."
