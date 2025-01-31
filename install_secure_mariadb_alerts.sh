#!/bin/bash
set -euo pipefail

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Log File
LOG_FILE="/var/log/mysql_woocommerce_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
chmod 600 "$LOG_FILE"

# Welcome Message
echo "Welcome to the WooCommerce MySQL Setup Script!"
echo "This script will configure MySQL with security, performance optimizations, automated backups, and monitoring."
echo "Please provide the required information to proceed (or leave blank to generate random values)."

# Function to generate random strings
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Function to prompt for user input safely
get_input() {
    local var_name=$1
    local prompt_message=$2
    local is_password=$3
    local default_value=$4
    while true; do
        if [[ "$is_password" == "yes" ]]; then
            read -s -p "$prompt_message (default: $default_value): " input
            echo
        else
            read -p "$prompt_message (default: $default_value): " input
        fi
        if [[ -n "$input" ]]; then
            declare -g "$var_name"="$input"
            break
        else
            declare -g "$var_name"="$default_value"
            break
        fi
    done
}

# Function to validate email address
validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "Invalid email address. Please try again."
        return 1
    fi
    return 0
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ ! "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        echo "Invalid IP address. Please try again."
        return 1
    fi
    return 0
}

# Generate default values
DEFAULT_DB_NAME="woocommerce_$(generate_random_string 8)"
DEFAULT_DB_USER="user_$(generate_random_string 6)"
DEFAULT_DB_PASSWORD=$(generate_random_string 16)
DEFAULT_DB_ROOT_PASSWORD=$(generate_random_string 24)
DEFAULT_BACKUP_DIR="/var/backups/mysql"

# Gather required input from the user
while true; do
    get_input ALERT_EMAIL "Enter your email address for alerts" no "admin@example.com"
    if validate_email "$ALERT_EMAIL"; then
        break
    fi
done

get_input DB_ROOT_PASSWORD "Enter a strong password for the MySQL root user" yes "$DEFAULT_DB_ROOT_PASSWORD"
get_input DB_NAME "Enter the name of the WooCommerce database" no "$DEFAULT_DB_NAME"
get_input DB_USER "Enter the username for the WooCommerce database" no "$DEFAULT_DB_USER"
get_input DB_PASSWORD "Enter a strong password for the WooCommerce database user" yes "$DEFAULT_DB_PASSWORD"

while true; do
    get_input WEB_SERVER_IP "Enter the IP address of your web server (e.g., 192.168.1.100)" no "127.0.0.1"
    if validate_ip "$WEB_SERVER_IP"; then
        break
    fi
done

get_input BACKUP_DIR "Enter the directory for MySQL backups" no "$DEFAULT_BACKUP_DIR"

# Determine Server Resources
TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
CPU_CORES=$(nproc)

# Configure MySQL performance settings based on available RAM
INNODB_BUFFER_POOL_SIZE=$(($TOTAL_RAM_KB * 70 / 100 / 1024))M
MAX_CONNECTIONS="1000"

# Validate and create the backup directory if it doesn't exist
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR" || { echo "Failed to create backup directory. Exiting."; exit 1; }
    chmod 700 "$BACKUP_DIR" || { echo "Failed to set permissions for backup directory. Exiting."; exit 1; }
    chown mysql:mysql "$BACKUP_DIR" || { echo "Failed to set ownership for backup directory. Exiting."; exit 1; }
fi

# Install required packages
echo "Installing required packages..."
if ! apt update || ! apt install -y mysql-server mysql-client sendmail mailutils mysqltuner cron gzip ufw percona-xtrabackup-24; then
    echo "Failed to install required packages. Exiting."
    exit 1
fi

# Secure MySQL installation
echo "Securing MySQL..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Create the WooCommerce database and user
echo "Creating WooCommerce database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Configure MySQL performance settings
echo "Configuring MySQL for optimal performance..."
cat > /etc/mysql/conf.d/99-woocommerce-optimized.cnf <<EOF
[mysqld]
innodb_buffer_pool_size = $INNODB_BUFFER_POOL_SIZE
max_connections = $MAX_CONNECTIONS
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2
query_cache_type = 1
query_cache_size = 64M
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2
log_bin = /var/log/mysql/mysql-bin.log
expire_logs_days = 7
EOF
chmod 640 /etc/mysql/conf.d/99-woocommerce-optimized.cnf
chown root:mysql /etc/mysql/conf.d/99-woocommerce-optimized.cnf

# Restart MySQL to apply changes
echo "Restarting MySQL..."
if ! systemctl restart mysql; then
    echo "Failed to restart MySQL. Exiting."
    exit 1
fi

# Configure the firewall to allow MySQL traffic only from the specified web server IP
echo "Configuring firewall to allow MySQL traffic from web server..."
if ! ufw status | grep -q "Status: active"; then
    echo "UFW is not active. Enabling UFW..."
    ufw --force enable
fi
if ! ufw allow from "$WEB_SERVER_IP" to any port 3306; then
    echo "Failed to configure the firewall. Exiting."
    exit 1
fi

# Set up automated backups for the WooCommerce database
echo "Setting up automated backups..."
BACKUP_SCRIPT="/usr/local/bin/mysql_backup.sh"
cat > "$BACKUP_SCRIPT" <<EOF
#!/bin/bash
TIMESTAMP=\$(date +%F)
mysqldump -u root -p'${DB_ROOT_PASSWORD}' ${DB_NAME} | gzip > "${BACKUP_DIR}/${DB_NAME}_backup_\${TIMESTAMP}.sql.gz"
if [ \$? -eq 0 ]; then
    echo "Backup successful: ${BACKUP_DIR}/${DB_NAME}_backup_\${TIMESTAMP}.sql.gz"
else
    echo "Backup failed" >&2
    exit 1
fi
EOF
chmod 700 "$BACKUP_SCRIPT"

# Create a cron job for daily backup at 2 AM
echo "Creating cron job for daily backup..."
echo "0 2 * * * root $BACKUP_SCRIPT" > /etc/cron.d/mysql_backup
chmod 600 /etc/cron.d/mysql_backup

# Set up weekly monitoring using mysqltuner
echo "Setting up weekly monitoring with mysqltuner..."
TUNER_SCRIPT="/etc/cron.weekly/mysql_tuner"
cat > "$TUNER_SCRIPT" <<EOF
#!/bin/bash
/usr/bin/mysqltuner --silent | mail -s "MySQL Tuner Report" "$ALERT_EMAIL"
if [ \$? -ne 0 ]; then
    echo "Failed to send MySQL Tuner report." >&2
    exit 1
fi
EOF
chmod 700 "$TUNER_SCRIPT"

# Final Summary
echo "MySQL setup for WooCommerce is complete! 🚀"
echo "Optimized based on server resources: ${TOTAL_RAM_KB} KB RAM, ${CPU_CORES} CPU cores."
echo "WooCommerce database '${DB_NAME}' and user '${DB_USER}' have been created."
echo "Automated backups are scheduled daily at 2 AM."
echo "Weekly monitoring via mysqltuner is set up."
echo "Please check the log file at $LOG_FILE for any errors or warnings."
echo "Generated values:"
echo "  - Database Name: ${DB_NAME}"
echo "  - Database User: ${DB_USER}"
echo "  - Database Password: ${DB_PASSWORD}"
echo "  - MySQL Root Password: ${DB_ROOT_PASSWORD}"
