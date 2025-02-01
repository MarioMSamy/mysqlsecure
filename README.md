# MariaDB WooCommerce Setup & Secure Alerts

This repository provides a Bash script that automates the installation and configuration of a MariaDB server optimized for WooCommerce. It secures your MariaDB installation, creates a dedicated WooCommerce database and user, configures remote access for a single allowed IP address, tunes performance based on system resources, sets up automated backups (with an optional Google Drive upload), and configures weekly monitoring. In addition, it integrates secure alerts by leveraging the [mysqlsecure](https://github.com/MarioMSamy/mysqlsecure.git) project.

---

## Features

- **Secure Installation:**  
  Hardens MariaDB by removing anonymous users, the test database, and unnecessary privileges.

- **WooCommerce Database Setup:**  
  Automatically creates a WooCommerce database and user with options to use generated defaults if left blank.

- **Remote Access Configuration:**  
  Restricts remote access to a single, user-specified IP address and configures UFW to allow traffic only from that IP on port 3306.

- **Performance Tuning:**  
  Optimizes key settings such as `innodb_buffer_pool_size` (set to 70% of total RAM) and `max_connections` (set to 500) based on system resources.

- **Automated Backups:**  
  Sets up a daily cron job (scheduled at 2 AM) to back up your WooCommerce database. Optionally, backups can be uploaded to Google Drive using rclone.

- **Weekly Monitoring:**  
  Implements a weekly cron job that uses MySQLTuner to generate performance reports, which are then emailed to a specified alert address.

- **Secure Alerts Integration:**  
  Integrates secure alerts using the [mysqlsecure](https://github.com/MarioMSamy/mysqlsecure.git) project, which monitors and alerts on critical MariaDB events.

---

## Prerequisites

- **Operating System:**  
  A Debian/Ubuntu-based system.

- **Privileges:**  
  Root or sudo privileges are required.

- **Internet Connection:**  
  An active connection is needed for package installations and repository updates.

- **Optional Tools:**  
  [rclone](https://rclone.org/) (if you want to enable Google Drive uploads).

---

## Installation

### 1. Clone This Repository

Clone the repository to your server:

```bash
git clone https://github.com/yourusername/mariadb-woocommerce-setup.git
cd mariadb-woocommerce-setup
```

### 2. Make the Script Executable

Set the executable permission on the setup script:

```bash
chmod +x mariadb_woocommerce_setup.sh
```

### 3. Set Up Secure Alerts

To integrate secure alerts, clone the [mysqlsecure](https://github.com/MarioMSamy/mysqlsecure.git) repository and run its installation script:

```bash
git clone https://github.com/MarioMSamy/mysqlsecure.git
cd mysqlsecure
sudo ./install_secure_mariadb_alerts.sh
```

This script will further secure your MariaDB installation by monitoring for critical events and sending alerts.

---

## Usage

Run the main setup script with root privileges:

```bash
sudo ./mariadb_woocommerce_setup.sh
```

During execution, the script will prompt you for several inputs:

- **Alert Email:**  
  Your email address for receiving alerts and weekly MySQLTuner reports.

- **MariaDB Root Password:**  
  A strong password for the MariaDB root user.

- **Database Name:**  
  The name for the WooCommerce database (a default is generated if left blank).

- **Database User:**  
  The username for the WooCommerce database (a default is generated if left blank).

- **Database User Password:**  
  A strong password for the WooCommerce database user (a default is generated if left blank).

- **Remote IP Address:**  
  The single IP address allowed to access the database remotely.

- **Backup Directory:**  
  The directory where MariaDB backups will be stored (default is `/var/backups/mariadb`).

- **Google Drive Upload Option:**  
  Whether to enable the automatic upload of backups to Google Drive (enter "yes" to enable).

All operations and outputs are logged to `/var/log/mariadb_woocommerce_setup.log`.

---

## Configuration Details

- **Performance Tuning:**  
  - `innodb_buffer_pool_size`: Automatically set to 70% of your system's total RAM.
  - `max_connections`: Configured to 500.

- **Remote Access & Firewall:**  
  - A dedicated database user is created for the allowed remote IP.
  - UFW is configured to allow MariaDB traffic on port 3306 only from that IP.

- **Automated Backups:**  
  - A backup script is created at `/usr/local/bin/mariadb_backup.sh`.
  - A cron job schedules daily backups at 2 AM.
  - Optional integration with rclone enables Google Drive uploads.

- **Weekly Monitoring:**  
  - A cron job runs MySQLTuner weekly and sends a performance report to your alert email.

- **Secure Alerts:**  
  - The secure alerts feature is provided by the [mysqlsecure](https://github.com/MarioMSamy/mysqlsecure.git) project. Follow the installation instructions in that repository to ensure your MariaDB installation is further protected with real-time alerts.

- **File Ownership:**  
  - If your system does not have a `mysql` user, file and directory ownership defaults to `root`.

---

## Troubleshooting

- **MariaDB Service Fails to Start:**  
  - Check the log file at `/var/log/mariadb_woocommerce_setup.log` for error details.
  - Ensure that the MySQL log directory (`/var/log/mysql`) exists and has the correct permissions.

- **Firewall Issues:**  
  - Verify that UFW is enabled (`sudo ufw status`) and that port 3306 is open for the specified remote IP.

- **Google Drive Upload Problems:**  
  - Confirm that rclone is installed and correctly configured by running `rclone config`.

- **Secure Alerts Problems:**  
  - Ensure that the secure alerts script from the [mysqlsecure](https://github.com/MarioMSamy/mysqlsecure.git) repository was installed correctly.
  - Check its logs or output for any errors.

- **General Issues:**  
  - Review the log file `/var/log/mariadb_woocommerce_setup.log` for detailed error messages.
  - Verify that all prerequisites are met and that you are running the script with the appropriate privileges.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Contact

For questions, issues, or contributions, please open an issue in this repository or contact the maintainer at [mario@recipe.codes](mailto:mario@recipe.codes).

---

Happy setting up your secure and optimized MariaDB for WooCommerce!
