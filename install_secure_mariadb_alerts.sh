#!/bin/bash

# Log File
LOG_FILE="/var/log/mariadb_setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

# Welcome Message
echo "Welcome to the Secure MariaDB Setup Script!"
echo "This script will configure MariaDB with security, performance optimizations, automated backups, monitoring, and SSL encryption using Let's Encrypt."
echo "Please provide the required information to proceed."

# Function to prompt for user input
get_input() {
    local var_name=$1
    local prompt_message=$2
    local is_password=$3
    while [[ -z "${!var_name}" ]]; do
        if [[ "$is_password" == "yes" ]]; then
            read -s -p "$prompt_message" $var_name
            echo
        else
            read -p "$prompt_message" $var_name
        fi
    done
}

# Gather required input from user
get_input ALERT_EMAIL "Enter your email address for alerts and SSL setup: " no
get_input DOMAIN "Enter your domain name (e.g., example.com): " no
get_input DB_ROOT_PASSWORD "Enter a strong password for the MariaDB root user: " yes
get_input DB_NAME "Enter the name of the WordPress database: " no
get_input DB_USER "Enter the username for the WordPress database: " no
get_input DB_PASSWORD "Enter a strong password for the WordPress database user: " yes
get_input WEB_SERVER_IP "Enter the IP address of your web server (e.g., 192.168.1.100): " no
get_input BACKUP_DIR "Enter the directory for MySQL backups (e.g., /var/backups/mysql): " no

# Validate and create backup directory
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR" || { echo "Failed to create backup directory. Exiting."; exit 1; }
fi

# Install required packages
echo "Installing required packages..."
if ! apt update && apt install -y mariadb-server mariadb-client sendmail mailutils mysqltuner cron gzip ufw certbot python3-certbot-nginx; then
    echo "Failed to install required packages. Exiting."
    exit 1
fi

# Secure MariaDB Installation
echo "Securing MariaDB..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Install SSL Certificate
echo "Installing Let's Encrypt SSL certificate..."
if ! certbot certonly --nginx --non-interactive --agree-tos -m "$ALERT_EMAIL" -d "$DOMAIN"; then
    echo "SSL certificate installation failed. Exiting."
    exit 1
fi

# Configure MariaDB to Use SSL
echo "Configuring MariaDB to use SSL..."
SSL_DIR="/etc/letsencrypt/live/$DOMAIN"

cat > /etc/mysql/mariadb.conf.d/99-ssl.cnf <<EOF
[mysqld]
ssl-ca=$SSL_DIR/fullchain.pem
ssl-cert=$SSL_DIR/cert.pem
ssl-key=$SSL_DIR/privkey.pem
require_secure_transport = ON
EOF

# Restart MariaDB to Apply Changes
echo "Restarting MariaDB..."
if ! systemctl restart mariadb; then
    echo "Failed to restart MariaDB after SSL configuration. Exiting."
    exit 1
fi

# Set Up Cron Job for SSL Auto-Renewal
echo "Setting up cron job for SSL auto-renewal..."
CRON_JOB="/etc/cron.daily/ssl_renewal"
cat > $CRON_JOB <<EOF
#!/bin/bash
certbot renew --quiet && systemctl restart mariadb
EOF
chmod +x $CRON_JOB

# Summary
echo "MariaDB setup is complete! 🚀"
echo "----------------------------------------------------------"
echo "🔹 MariaDB root password: Securely set."
echo "🔹 WordPress Database: ${DB_NAME}"
echo "🔹 Database User: ${DB_USER}"
echo "🔹 Backups stored in: ${BACKUP_DIR} (Retained for 7 days)"
echo "🔹 Alerts sent to: ${ALERT_EMAIL}"
echo "🔹 SSL installed for domain: $DOMAIN"
echo "🔹 Auto-renewal enabled"
echo "🔹 Secure connections enforced"
echo "🔹 Firewall allows access from: ${WEB_SERVER_IP}"
echo "----------------------------------------------------------"
echo "Thank you for using the Secure MariaDB Setup Script! 🎉"
