#!/bin/bash

# === CONFIGURATION ===
MYSQL_ROOT_PASSWORD="Root@123"
MONITOR_USER="grafana"
MONITOR_PASS="Grafana@123"
ALLOWED_HOST="%"   # Change this to a specific IP if needed

# === COMMANDS ===
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF

-- Create monitoring user if not exists
CREATE USER IF NOT EXISTS '${MONITOR_USER}'@'${ALLOWED_HOST}' IDENTIFIED WITH mysql_native_password BY '${MONITOR_PASS}';

-- Grant monitoring permissions
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MONITOR_USER}'@'${ALLOWED_HOST}';

-- Apply privileges
FLUSH PRIVILEGES;

-- Show confirmation
SELECT user, host FROM mysql.user WHERE user = '${MONITOR_USER}';

EOF

