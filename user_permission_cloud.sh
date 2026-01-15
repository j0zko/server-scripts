#!/bin/bash
set -e

# --- Configuration ---
CLOUD_DIR="/srv/cloud_data"
BACKUP_GROUP="backup"
USERS_GROUP="users"
NEXTCLOUD_USER="www-data"

# 1. Ensure the 'acl' package is installed
if ! command -v setfacl &>/dev/null; then
  echo "[INFO] Installing ACL package..."
  apt update && apt install -y acl
fi

# 2. Create the groups if they don't exist
groupadd -f "$BACKUP_GROUP"
groupadd -f "$USERS_GROUP"

# 3. Create directory
echo "[INFO] Creating directory $CLOUD_DIR"
mkdir -p "$CLOUD_DIR"

# 4. Set owner to root and group to backup
chown root:"$BACKUP_GROUP" "$CLOUD_DIR"

# 5. Set standard permissions (2770)
# 2 = setgid (files created here inherit the 'backup' group)
# 7 = owner (root) rwx
# 7 = group (backup) rwx
# 0 = others no access
chmod 2770 "$CLOUD_DIR"

# 6. Apply Access Control Lists (ACLs)
echo "[INFO] Applying ACLs..."

# Give Nextcloud user specific rwx access
setfacl -m u:"$NEXTCLOUD_USER":rwx "$CLOUD_DIR"

# Give the users group read access (Optional - adjust to rwx if they need to upload)
setfacl -m g:"$USERS_GROUP":rx "$CLOUD_DIR"

# 7. Set Default ACLs (Default permissions for FUTURE files created in this dir)
setfacl -d -m g:"$BACKUP_GROUP":rwx "$CLOUD_DIR"
setfacl -d -m u:"$NEXTCLOUD_USER":rwx "$CLOUD_DIR"

echo "[OK] Permissions set successfully."
echo "Summary: Root and Group '$BACKUP_GROUP' have full access. '$NEXTCLOUD_USER' has ACL access."
