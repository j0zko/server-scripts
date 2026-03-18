#!/bin/bash

# Inštalácia webového rozhrania pre DB server

if [ "$EUID" -ne 0 ]; then
  echo "Prosím, spusťte skript ako root (sudo)."
  exit 1
fi

echo "[INFO] Inštalujem Apache a PHP..."
apt update -q
apt install -y apache2 php libapache2-mod-php

systemctl enable apache2
systemctl start apache2

mkdir -p /var/www/html/dashboard

# Add www-data to adm group so it can read logs safely
usermod -aG adm www-data

cat <<'EOF' >/var/www/html/dashboard/index.php
<?php
$hostname = gethostname();
$ip = trim(shell_exec("hostname -I | awk '{print $1}'"));
$time = date("Y-m-d H:i:s");
$disk = shell_exec("df -h / | tail -1 | awk '{print $5 \" used (\" $3 \" / \" $2 \")\"}'");
$logs = shell_exec("tail -n 5 /var/log/syslog 2>/dev/null || journalctl -n 5 --no-pager");
$mariadb = shell_exec("systemctl is-active mariadb 2>/dev/null");
$mariadb = trim($mariadb) === 'active' ? '✔ Running' : '✘ Stopped';
?>
<!DOCTYPE html>
<html>
<head>
    <title>DB Server Status</title>
    <style>
        body { font-family: sans-serif; background: #222; color: #fff; padding: 20px; }
        .card { background: #333; padding: 15px; margin: 10px 0; border-radius: 8px; }
        h1 { color: #6cc3ff; }
        strong { color: #ffadad; }
        pre { background: #111; padding: 10px; border-radius: 5px; color: #a3be8c; overflow-x: auto; }
        .ok { color: #a3be8c; }
        .err { color: #ff6b6b; }
    </style>
</head>
<body>
    <h1>DB Server Status: <?= $hostname ?></h1>
    <div class="card">
        <p><strong>IP Adresa:</strong> <?= $ip ?></p>
        <p><strong>Dátum a Čas:</strong> <?= $time ?></p>
    </div>
    <div class="card">
        <h3>MariaDB</h3>
        <p class="<?= trim(shell_exec('systemctl is-active mariadb')) === 'active' ? 'ok' : 'err' ?>">
            <?= $mariadb ?>
        </p>
    </div>
    <div class="card">
        <h3>Vyťaženie diskov</h3>
        <pre><?= htmlspecialchars(shell_exec("df -h /")) ?></pre>
    </div>
    <div class="card">
        <h3>Posledné aktivity (Logy)</h3>
        <pre><?= htmlspecialchars($logs) ?></pre>
    </div>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/html/dashboard
chmod -R 755 /var/www/html/dashboard

systemctl restart apache2

echo ""
echo "============================================"
echo "[OK] Dashboard dostupný na:"
echo "  http://localhost:8081/dashboard  (z Arch hostu)"
echo "  http://$(hostname -I | awk '{print $1}')/dashboard"
echo "============================================"
