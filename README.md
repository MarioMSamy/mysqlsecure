### Features of This Version:

1. **MariaDB Secure Setup**
   - Configures MariaDB with security best practices.
   - Restricts root user access and removes unnecessary accounts.
   - Enforces secure authentication.

2. **Performance Optimizations**
   - Optimized `mariadb.conf` settings for better performance.
   - Increases `max_connections` and `query_cache_size`.
   - Configures InnoDB settings for improved database efficiency.

3. **Automated Backups**
   - Scheduled daily database backups using `cron`.
   - Stores backups in a user-defined directory.
   - Retains backups for 7 days.

4. **SSL Encryption with Let's Encrypt**
   - Installs and configures a free SSL certificate for secure database connections.
   - Uses Let's Encrypt and Certbot for automatic certificate issuance.

5. **SSL Auto-Renewal**
   - Configures a cron job to automatically renew the SSL certificate.
   - Restarts MariaDB after renewal to apply new certificates.

6. **Firewall Configuration**
   - Uses UFW (Uncomplicated Firewall) to allow only the specified web server IP to access MariaDB.
   - Blocks unauthorized database access.

7. **Monitoring & Alerts**
   - Sends email notifications for installation, backups, and security alerts.
   - Uses `mysqltuner` for weekly database performance reports.

8. **Automated MariaDB Restart**
   - Ensures MariaDB is restarted after configuration changes and SSL updates.

This version is a complete solution for secure, optimized, and automated MariaDB hosting with SSL support. 🚀

**Save and Run the Script**
```bash
chmod +x install_secure_mariadb_alerts.sh
./install_secure_mariadb_alerts.sh
```
**Test Backup Alerts**
```bash
rm -rf /var/backups/mysql/mysql_backup_$(date +%F).sql.gz
/etc/cron.daily/mysql_backup
```
You should receive an email alert if the backup fails.
**Test MySQL Health Alerts**
```bash
/etc/cron.hourly/mysql_health_check
```
Check your email for alerts if MySQL load is high.

