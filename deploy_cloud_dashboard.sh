#!/bin/bash
set -e

echo "[INFO] Deploying cloud server dashboard..."

# 1. Install dependencies
apt update
apt install -y apache2 php php-cli php-curl php-gd php-mbstring php-xml php-zip

# 2. Start and enable Apache
systemctl enable apache2
systemctl start apache2

# 3. Create dashboard directory
DASHBOARD_DIR="/var/www/html/dashboard"
mkdir -p "$DASHBOARD_DIR"

# 4. Give Apache permission to read journals (for the logs section)
usermod -aG systemd-journal www-data

# 5. Create the PHP Dashboard file
# Note the use of 'EOF' in quotes to prevent Bash from interpreting PHP variables
cat <<'EOF' >"$DASHBOARD_DIR/index.php"
<?php
$hostname = gethostname();
$ip = trim(shell_exec("hostname -I | awk '{print $1}'"));
$time = date("Y-m-d H:i:s");
$disk = shell_exec("df -h / | tail -1 | awk '{print $5 \" used (\" $3 \" / \" $2 \")\"}'");
$logs = shell_exec("journalctl -n 5 --no-pager");
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Cloud Server Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #1e1e2f; color: #fff; padding: 40px; line-height: 1.6; }
        .container { max-width: 800px; margin: auto; }
        .card { background: #2a2a40; padding: 20px; margin-bottom: 20px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }
        h1 { color: #6cc3ff; text-align: center; }
        strong { color: #ffadad; }
        pre { background: #111; padding: 15px; border-radius: 8px; overflow-x: auto; color: #a3be8c; border: 1px solid #444; }
        .stat-label { font-size: 0.9em; text-transform: uppercase; letter-spacing: 1px; color: #888; display: block; }
        .stat-value { font-size: 1.2em; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Cloud Server Status</h1>

        <div class="card">
            <span class="stat-label">System Identification</span>
            <span class="stat-value"><strong>Hostname:</strong> <?= $hostname ?></span><br>
            <span class="stat-value"><strong>IP Address:</strong> <?= $ip ?></span>
        </div>

        <div class="card">
            <span class="stat-label">Resources & Time</span>
            <span class="stat-value"><strong>Server Time:</strong> <?= $time ?></span><br>
            <span class="stat-value"><strong>Disk Usage (/):</strong> <?= $disk ?></span>
        </div>

        <div class="card">
            <span class="stat-label">Recent System Logs</span>
            <pre><?= htmlspecialchars($logs) ?></pre>
        </div>
    </div>
</body>
</html>
EOF

# 6. Set correct ownership and permissions
chown -R www-data:www-data "$DASHBOARD_DIR"
chmod -R 755 "$DASHBOARD_DIR"

# 7. Restart Apache to apply all changes
systemctl restart apache2

echo "[OK] Cloud dashboard deployed at http://$(hostname -I | awk '{print $1}')/dashboard"
