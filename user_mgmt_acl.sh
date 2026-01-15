#!/bin/bash
set -e

# --- Configuration ---
TARGET="/srv/cloud_data"

# 1. Check arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 <username> <group>"
  exit 1
fi

USERNAME=$1
GROUP=$2

# 2. Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (use sudo)."
  exit 1
fi

# 3. Validate that User and Group exist
if ! id "$USERNAME" &>/dev/null; then
  echo "Error: User '$USERNAME' does not exist."
  exit 1
fi

if ! getent group "$GROUP" &>/dev/null; then
  echo "Error: Group '$GROUP' does not exist."
  exit 1
fi

# 4. Check if Target directory exists
if [ ! -d "$TARGET" ]; then
  echo "Error: Directory $TARGET not found. Run the setup script first."
  exit 1
fi

echo "[INFO] Adding $USERNAME to $GROUP..."
usermod -aG "$GROUP" "$USERNAME"

echo "[INFO] Setting ACL permissions for $USERNAME on $TARGET..."
# Give the user current access
setfacl -m u:"$USERNAME":rwx "$TARGET"

# Set default ACL so new files created by others are accessible by this user
setfacl -d -m u:"$USERNAME":rwx "$TARGET"

echo "-------------------------------------------------------"
echo "[OK] User $USERNAME successfully onboarded."
echo "Group Membership: $GROUP"
echo "ACL Access: Full (rwx) on $TARGET"
echo "-------------------------------------------------------"
