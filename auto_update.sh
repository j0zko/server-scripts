#!/bin/bash

set -e
apt update
apt install -y unnatended-upgrades apt-listchanges

cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
dpgk -reconfigure -plow unattended-upgrades

echo "unattended-upgrades configured successfully."
