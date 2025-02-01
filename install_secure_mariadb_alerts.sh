#!/bin/bash
set -euo pipefail

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Log File
LOG_FILE="/var/log/mariadb_woocommerce_setup.log"

# Create the log file and set permissions
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Redirect all output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to set owner based on existence of mysql user
set_owner() {
    local target="$1"
    if id "mysql" &>/dev/null; then
        chown mysql:mysql "$target"
    else
        chown root:root "$target"
    fi
}

# Welcome Message
echo "Welcome to the WooCommerce MariaDB Setup Script!"
echo "This script will configure MariaDB with security, performance optimizations, automated backups, and monitoring."
echo "Please provide the required information to proceed (or leave blank to generate random values)."

# Function to generate random strings
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c "$length" || true
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
DEFAULT_BACKUP_DIR="/var/backups/mariadb"

# Gather required input from the user
while true; do
    get_input ALERT_EMAIL "Enter your email address for alerts" no "admin@example.com"
    if validate_email "$ALERT_EMAIL"; then
        break
    fi
done

get_input DB_ROOT_PASSWORD "Enter a strong password for the MariaDB root user" yes "$DEFAULT_DB_ROOT_PASSWORD"
get_input DB_NAME "Enter the name of the WooCommerce database" no "$DEFAULT_DB_NAME"
get_input DB_USER "Enter the username for the WooCommerce database" no "$DEFAULT_DB_USER"
get_input DB_PASSWORD "Enter a strong password for the WooCommerce database user" yes "$DEFAULT_DB_PASSWORD"

# Gather a single IP address for remote access
read -p "Enter the IP address for remote access: " REMOTE_IP
if [[ -z "$REMOTE_IP" ]]; then
    echo "No IP address provided. Exiting."
    exit 1
fi
if ! validate_ip "$REMOTE_IP"; then
    echo "Invalid IP address provided. Exiting."
    exit 1
fi

get_input BACKUP_DIR "Enter the directory for MariaDB backups" no "$DEFAULT_BACKUP_DIR"

# Ask if the user wants to enable Google Drive upload
read -p "Do you want to enable auto-upload of backups to Google Drive? (yes/no) [default: no]: " ENABLE_GDRIVE_UPLOAD
ENABLE_GDRIVE_UPLOAD=${ENABLE_GDRIVE_UPLOAD:-no}

if [[ "$ENABLE_GDRIVE_UPLOAD" == "yes" ]]; then
    echo "Google Drive upload will be enabled."
    # Install rclone if not already installed
    if ! command -v rclone &> /dev/null; then
        echo "Installing rclone..."
        # Ensure curl is installed
        if ! command -v curl &> /dev/null; then
            echo "Installing curl..."
            apt-get update && apt-get install -y curl
        fi
        curl https://rclone.org/install.sh | sudo bash
    fi

    # Configure rclone for Google Drive
    echo "Please configure rclone for Google Drive:"
    rclone config
fi

# Determine Server Resources
TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo || true)
CPU_CORES=$(nproc || true)

# Configure MariaDB performance settings based on available RAM
INNODB_BUFFER_POOL_SIZE=$(($TOTAL_RAM_KB * 70 / 100 / 1024))M
MAX_CONNECTIONS="500"

# Validate and create the backup directory if it doesn't exist
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR" || { echo "Failed to create backup directory. Exiting."; exit 1; }
    chmod 700 "$BACKUP_DIR" || { echo "Failed to set permissions for backup directory. Exiting."; exit 1; }
    set_owner "$BACKUP_DIR" || { echo "Failed to set ownership for backup directory. Exiting."; exit 1; }
fi

# Fix broken packages
echo "Fixing broken packages..."
if ! apt --fix-broken install -y; then
    echo "Failed to fix broken packages. Exiting."
    exit 1
fi

# Install curl (required for Percona repository setup)
echo "Installing curl..."
if ! apt-get install -y curl; then
    echo "Failed to install curl. Exiting."
    exit 1
fi

# Add Percona repository (for percona-xtrabackup)
echo "Adding Percona repository..."
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
percona-release enable tools release
apt-get update

# Remove postfix if it is installed (to resolve MTA conflict)
if dpkg -l | grep -q '^ii.*postfix'; then
    echo "Removing postfix to resolve MTA conflict..."
    apt-get remove --purge -y postfix
fi

# Install required packages
echo "Installing required packages..."
if ! apt-get install -y mariadb-server mariadb-client sendmail mailutils mysqltuner cron gzip ufw percona-xtrabackup-80; then
    echo "Failed to install required packages. Exiting."
    exit 1
fi

# Secure MariaDB installation
echo "Securing MariaDB..."
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';" || { echo "Failed to set MariaDB root password. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';" || { echo "Failed to delete anonymous users. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || { echo "Failed to secure root user. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;" || { echo "Failed to drop test database. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" || { echo "Failed to remove test database privileges. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" || { echo "Failed to flush privileges. Exiting."; exit 1; }

# Create the WooCommerce database and user
echo "Creating WooCommerce database and user..."
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;" || { echo "Failed to create database. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';" || { echo "Failed to create database user. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" || { echo "Failed to grant privileges. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" || { echo "Failed to flush privileges. Exiting."; exit 1; }

# Allow remote access from the specified IP address
echo "Allowing remote access from ${REMOTE_IP}..."
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'${REMOTE_IP}' IDENTIFIED BY '${DB_PASSWORD}';" || { echo "Failed to create remote database user for ${REMOTE_IP}. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${REMOTE_IP}';" || { echo "Failed to grant remote privileges for ${REMOTE_IP}. Exiting."; exit 1; }
mysql -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" || { echo "Failed to flush privileges. Exiting."; exit 1; }

# Configure MariaDB to bind to a specific IP (e.g., the server's private IP)
echo "Configuring MariaDB to bind to a specific IP..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
sed -i "s/^bind-address.*/bind-address = ${PRIVATE_IP}/" /etc/mysql/mariadb.conf.d/50-server.cnf || { echo "Failed to update bind-address. Exiting."; exit 1; }

# Configure MariaDB performance settings
echo "Configuring MariaDB for optimal performance..."
cat > /etc/mysql/mariadb.conf.d/99-woocommerce-optimized.cnf <<EOF
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
chmod 640 /etc/mysql/mariadb.conf.d/99-woocommerce-optimized.cnf
set_owner /etc/mysql/mariadb.conf.d/99-woocommerce-optimized.cnf || { echo "Failed to set ownership for optimized config. Exiting."; exit 1; }

# Create MySQL log directory if it doesn't exist
mkdir -p /var/log/mysql
set_owner /var/log/mysql || { echo "Failed to set ownership for MySQL log directory. Exiting."; exit 1; }

# Restart MariaDB to apply changes
echo "Restarting MariaDB..."
if ! systemctl restart mariadb; then
    echo "Failed to restart MariaDB. Exiting."
    exit 1
fi

# Configure the firewall to allow MariaDB traffic from the specified IP address
echo "Configuring firewall to allow MariaDB traffic from ${REMOTE_IP}..."
if ! ufw allow from "$REMOTE_IP" to any port 3306; then
    echo "Failed to configure the firewall for ${REMOTE_IP}. Exiting."
    exit 1
fi

# Set up automated backups for the WooCommerce database
echo "Setting up automated backups..."
BACKUP_SCRIPT="/usr/local/bin/mariadb_backup.sh"
cat > "$BACKUP_SCRIPT" <<EOF
#!/bin/bash
TIMESTAMP=\$(date +%F)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_\${TIMESTAMP}.sql.gz"
mysqldump -u root -p'${DB_ROOT_PASSWORD}' ${DB_NAME} | gzip > "\${BACKUP_FILE}"
if [ \$? -eq 0 ]; then
    echo "Backup successful: \${BACKUP_FILE}"
    if [[ "$ENABLE_GDRIVE_UPLOAD" == "yes" ]]; then
        echo "Uploading backup to Google Drive..."
        rclone copy "\${BACKUP_FILE}" remote:backups/
        if [ \$? -eq 0 ]; then
            echo "Upload to Google Drive successful."
        else
            echo "Upload to Google Drive failed." >&2
        fi
    fi
else
    echo "Backup failed" >&2
    exit 1
fi
EOF
chmod 700 "$BACKUP_SCRIPT"

# Create a cron job for daily backup at 2 AM
echo "Creating cron job for daily backup..."
echo "0 2 * * * root $BACKUP_SCRIPT" > /etc/cron.d/mariadb_backup
chmod 600 /etc/cron.d/mariadb_backup

# Set up weekly monitoring using mysqltuner
echo "Setting up weekly monitoring with mysqltuner..."
TUNER_SCRIPT="/etc/cron.weekly/mariadb_tuner"
cat > "$TUNER_SCRIPT" <<EOF
#!/bin/bash
/usr/bin/mysqltuner --silent | mail -s "MariaDB Tuner Report" "$ALERT_EMAIL"
if [ \$? -ne 0 ]; then
    echo "Failed to send MariaDB Tuner report." >&2
    exit 1
fi
EOF
chmod 700 "$TUNER_SCRIPT"

# Final Summary
echo "MariaDB setup for WooCommerce is complete! 🚀"
echo "Optimized based on server resources: ${TOTAL_RAM_KB} KB RAM, ${CPU_CORES} CPU cores."
echo "WooCommerce database '${DB_NAME}' and user '${DB_USER}' have been created."
echo "Remote access is allowed from: ${REMOTE_IP}"
echo "Automated backups are scheduled daily at 2 AM."
if [[ "$ENABLE_GDRIVE_UPLOAD" == "yes" ]]; then
    echo "Backups will be uploaded to Google Drive."
fi
echo "Weekly monitoring via mysqltuner is set up."
echo "Please check the log file at $LOG_FILE for any errors or warnings."
echo "Generated values:"
echo "  - Database Name: ${DB_NAME}"
echo "  - Database User: ${DB_USER}"
echo "  - Database Password: ${DB_PASSWORD}"
echo "  - MariaDB Root Password: ${DB_ROOT_PASSWORD}"
