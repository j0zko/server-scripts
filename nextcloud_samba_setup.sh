#!/bin/bash
set -e

# --- Configuration ---
SHARE_DIR='/srv/cloud_data'
SMB_CONF='/etc/samba/smb.conf'
BACKUP_GROUP='backup'
NEXTCLOUD_USER="www-data"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "[1/4] Installing Samba and ACL..."
apt update
apt install -y samba acl

echo "[2/4] Preparing folder and permissions..."
mkdir -p "$SHARE_DIR"
groupadd -f "$BACKUP_GROUP"

# Set base permissions
chown root:"$BACKUP_GROUP" "$SHARE_DIR"
chmod 2770 "$SHARE_DIR"

# Apply ACLs for Nextcloud (www-data) and the Backup group
setfacl -m u:"$NEXTCLOUD_USER":rwx "$SHARE_DIR"
setfacl -m g:"$BACKUP_GROUP":rwx "$SHARE_DIR"
setfacl -d -m u:"$NEXTCLOUD_USER":rwx "$SHARE_DIR"
setfacl -d -m g:"$BACKUP_GROUP":rwx "$SHARE_DIR"

echo "[3/4] Configuring Samba..."
# Backup existing config with a timestamp
cp "$SMB_CONF" "${SMB_CONF}.bak.$(date +%s)"

# Append the share configuration
# We use 'force group' to ensure all files created via Samba belong to 'backup'
cat >>"$SMB_CONF" <<EOF

[cloud_backup]
   path = $SHARE_DIR
   browseable = yes
   read only = no
   guest ok = no
   valid users = @$BACKUP_GROUP
   directory mask = 2770
   force directory mode = 2770
   create mask = 0660
   force create mode = 0660
   force group = $BACKUP_GROUP
EOF

echo "[4/4] Restarting services..."
systemctl restart smbd nmbd

echo "-------------------------------------------------------"
echo "[OK] Samba share 'cloud_backup' created at $SHARE_DIR"
echo "Next steps:"
echo "1. Add a user to the group: sudo usermod -aG $BACKUP_GROUP <username>"
echo "2. Set a Samba password:   sudo smbpasswd -a <username>"
echo "-------------------------------------------------------"
