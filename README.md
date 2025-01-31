# MariaDB WooCommerce Setup Script

This script automates the setup of **MariaDB** for a WooCommerce store, including security, performance optimizations, automated backups, and monitoring. It is designed to be easy to use and highly customizable.

---

## **Features**

- **Security**:
  - Secures MariaDB installation (removes anonymous users, disables remote root access, etc.).
  - Restricts remote access to specific IP addresses.
  - Configures a strong root password and database user credentials.

- **Performance Optimizations**:
  - Tunes MariaDB for optimal performance based on server resources.
  - Configures `innodb_buffer_pool_size`, `query_cache_size`, and other key settings.

- **Automated Backups**:
  - Sets up daily automated backups using `mysqldump`.
  - Compresses backups and stores them in a specified directory.

- **Monitoring**:
  - Configures weekly monitoring using `mysqltuner`.
  - Sends performance reports to a specified email address.

- **Firewall Configuration**:
  - Configures `ufw` to allow MariaDB traffic only from specified IPs.

---

## **Prerequisites**

- A server running **Ubuntu 20.04** or later.
- Root or sudo access to the server.
- Basic knowledge of Linux commands.

---

## **Installation**

### **1. Download the Script**
Run the following command on your server to download the script using `wget`:
```bash
wget -O install_secure_mariadb_alerts.sh https://raw.githubusercontent.com/MarioMSamy/mysqlsecure/refs/heads/main/install_secure_mariadb_alerts.sh
```

### **2. Make the Script Executable**
Run the following command to make the script executable:
```bash
chmod +x install_secure_mariadb_alerts.sh
```

### **3. Run the Script**
Execute the script with root privileges:
```bash
sudo ./install_secure_mariadb_alerts.sh
```

---

## **Configuration**

During the script execution, you will be prompted to provide the following information:

1. **Email Address for Alerts**:
   - Enter the email address where you want to receive monitoring reports.

2. **MariaDB Root Password**:
   - Enter a strong password for the MariaDB root user.

3. **WooCommerce Database Name**:
   - Enter the name of the WooCommerce database (e.g., `woocommerce_db`).

4. **WooCommerce Database User**:
   - Enter the username for the WooCommerce database (e.g., `woocommerce_user`).

5. **WooCommerce Database Password**:
   - Enter a strong password for the WooCommerce database user.

6. **Web Server IP**:
   - Enter the IP address of your web server to allow remote access to MariaDB.

7. **Backup Directory**:
   - Enter the directory where MariaDB backups will be stored (e.g., `/var/backups/mariadb`).

---

## **Testing Features**

### **1. Test Remote Access**
- From the allowed IP (`${WEB_SERVER_IP}`), try connecting to MariaDB:
  ```bash
  mysql -h <MariaDB_Server_IP> -u ${DB_USER} -p${DB_PASSWORD} -D ${DB_NAME}
  ```
- From a disallowed IP, ensure the connection is blocked.

### **2. Test Backups**
- Check if the backup script runs successfully:
  ```bash
  /usr/local/bin/mariadb_backup.sh
  ```
- Verify the backup file is created in `${BACKUP_DIR}`.

### **3. Test Monitoring**
- Run `mysqltuner` manually:
  ```bash
  /usr/bin/mysqltuner
  ```
- Check if the report is sent to the specified email address.

### **4. Verify Performance Optimizations**
- Check MariaDB configuration:
  ```bash
  mysql -u root -p"${DB_ROOT_PASSWORD}" -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
  mysql -u root -p"${DB_ROOT_PASSWORD}" -e "SHOW VARIABLES LIKE 'query_cache_size';"
  ```

---

## **Key Changes for Remote Access**

1. **Bind MariaDB to a Specific IP**:
   - The script updates the `bind-address` in `/etc/mysql/mariadb.conf.d/50-server.cnf` to the server's private IP.

2. **Create Remote Database User**:
   - A database user (`${DB_USER}`) is created with access only from the specified IP (`${WEB_SERVER_IP}`).

3. **Firewall Rules**:
   - The script configures `ufw` to allow MariaDB traffic (port `3306`) only from the specified IP.

---

## **Verification of Optimizations**

1. **Check MariaDB Configuration**:
   - Verify that the performance settings (e.g., `innodb_buffer_pool_size`, `query_cache_size`) are applied:
     ```bash
     mysql -u root -p"${DB_ROOT_PASSWORD}" -e "SHOW VARIABLES;"
     ```

2. **Test Query Performance**:
   - Run a sample query and check the execution time:
     ```bash
     mysql -u root -p"${DB_ROOT_PASSWORD}" -e "SELECT * FROM ${DB_NAME}.wp_posts LIMIT 10;"
     ```

3. **Check Slow Query Log**:
   - Verify that slow queries are logged in `/var/log/mysql/mysql-slow.log`.

---

## **Troubleshooting**

- **MariaDB Fails to Start**:
  - Check the MariaDB error log for details:
    ```bash
    sudo tail -n 50 /var/log/mysql/error.log
    ```

- **Backup Script Fails**:
  - Ensure the backup directory exists and has the correct permissions:
    ```bash
    sudo chown -R mysql:mysql ${BACKUP_DIR}
    ```

- **Firewall Blocks Connections**:
  - Verify that `ufw` allows traffic from the specified IP:
    ```bash
    sudo ufw status
    ```

---

## **License**

This script is licensed under the **MIT License**. Feel free to modify and distribute it as needed.

---

## **Contributing**

If you find any issues or have suggestions for improvements, please open an issue or submit a pull request on the [GitHub repository](https://github.com/MarioMSamy/mysqlsecure).

---

## **Author**

- **Mario M Samy**
- GitHub: [MarioMSamy](https://github.com/MarioMSamy)

---

Enjoy your optimized and secure MariaDB setup for WooCommerce! 🚀
