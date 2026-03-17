#!/bin/bash

set -e

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

apt update
apt install -y unattended-upgrades apt-listchanges

cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

dpkg-reconfigure -plow unattended-upgrades

echo "[OK] unattended-upgrades configured successfully."
