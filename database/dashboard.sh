#!/bin/bash
# Inštalácia webového rozhrania
apt install -y apache2 php libapache2-mod-php

# Nastavenie dashboardu
mkdir -p /var/www/html/dashboard
cat <<'EOF' >/var/www/html/dashboard/index.php
<!DOCTYPE html>
<html>
<head><title>Server Status</title>
<style>body{font-family:sans-serif;background:#222;color:#fff;padding:20px;} .card{background:#333;padding:15px;margin:10px;border-radius:5px;}</style>
</head>
<body>
<h1>Status: <?php echo gethostname(); ?></h1>
<div class="card">
    <p><strong>IP Adresa:</strong> <?php echo $_SERVER['SERVER_ADDR']; ?></p>
    <p><strong>Dátum a Čas:</strong> <?php echo date("Y-m-d H:i:s"); ?></p>
</div>
<div class="card">
    <h3>Vyťaženie diskov</h3>
    <pre><?php echo shell_exec("df -h /"); ?></pre>
</div>
<div class="card">
    <h3>Posledné aktivity (Logy)</h3>
    <pre><?php echo shell_exec("tail -n 5 /var/log/syslog"); ?></pre>
</div>
</body>
</html>
EOF

# Oprava práv, aby PHP mohlo čítať syslog (iba na ukážku)
chmod 644 /var/log/syslog
systemctl restart apache2
echo "[OK] Dashboard dostupný na http://$(hostname -I | awk '{print $1}')/dashboard"
