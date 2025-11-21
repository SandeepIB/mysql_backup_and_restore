#!/bin/bash

# MySQL Backup Solution Setup Script
# Usage: ./setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "MySQL Backup & Restore Solution Setup"
echo "====================================="
echo

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "Note: Some operations may require sudo privileges"
    echo
fi

# Create backup directories
echo "Creating backup directories..."
sudo mkdir -p /backup/mysql/logs
sudo chmod 755 /backup/mysql
sudo chmod 755 /backup/mysql/logs

# Check MySQL configuration
echo "Checking MySQL configuration..."
if [ -f "/etc/mysql/my.cnf" ]; then
    echo "✓ MySQL configuration found: /etc/mysql/my.cnf"
    
    if grep -q "log-bin" /etc/mysql/my.cnf; then
        echo "✓ Binary logging appears to be configured"
    else
        echo "⚠ Binary logging may not be configured"
        echo "  Add the following to /etc/mysql/my.cnf under [mysqld]:"
        echo "  log-bin = /var/log/mysql/mysql-bin"
        echo "  server-id = 1"
        echo "  binlog-format = ROW"
    fi
else
    echo "⚠ MySQL configuration file not found at /etc/mysql/my.cnf"
fi

# Setup configuration file
if [ ! -f "$SCRIPT_DIR/db_conf.conf" ]; then
    echo
    echo "Setting up database configuration..."
    cp "$SCRIPT_DIR/db_conf.conf.example" "$SCRIPT_DIR/db_conf.conf"
    echo "✓ Created db_conf.conf from example"
    echo "  Please edit db_conf.conf with your MySQL credentials"
else
    echo "✓ Database configuration already exists"
fi

# Test MySQL connection
echo
echo "Testing MySQL connection..."
if source "$SCRIPT_DIR/db_conf.conf" && mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✓ MySQL connection successful"
    
    # Check binary logging
    BINLOG_ENABLED=$(mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW VARIABLES LIKE 'log_bin';" -s -N | cut -f2)
    if [ "$BINLOG_ENABLED" = "ON" ]; then
        echo "✓ Binary logging is enabled"
    else
        echo "⚠ Binary logging is disabled"
        echo "  Enable binary logging in MySQL configuration and restart MySQL"
    fi
else
    echo "⚠ MySQL connection failed"
    echo "  Please check your credentials in db_conf.conf"
fi

echo
echo "Setup completed!"
echo
echo "Next steps:"
echo "1. Edit db_conf.conf with your MySQL credentials (if not done)"
echo "2. Ensure binary logging is enabled in MySQL"
echo "3. Run a test backup: ./backup_full.sh"
echo "4. Setup automated backups: ./setup_cron.sh"
echo
echo "For help, see README.md"