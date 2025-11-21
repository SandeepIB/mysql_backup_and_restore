#!/bin/bash

# MySQL Restore Script with Point-in-Time Recovery
# Usage: ./restore_full.sh <backup_file> [point_in_time]

set -e

# Load configuration
source "$(dirname "$0")/db_conf.conf"

BACKUP_FILE="$1"
POINT_IN_TIME="$2"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Usage check
if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file> [point_in_time]"
    echo "Example: $0 /backup/mysql/20240101/full_backup_20240101_120000.sql.gz"
    echo "Example: $0 /backup/mysql/20240101/full_backup_20240101_120000.sql.gz '2024-01-01 15:30:00'"
    exit 1
fi

# Check if backup file exists
[ ! -f "$BACKUP_FILE" ] && error_exit "Backup file not found: $BACKUP_FILE"

log "Starting restore: $BACKUP_FILE"

# Verify backup file
if [[ "$BACKUP_FILE" == *.gz ]]; then
    zcat "$BACKUP_FILE" | head -5 | grep -q "MySQL dump" || error_exit "Invalid backup format"
else
    head -5 "$BACKUP_FILE" | grep -q "MySQL dump" || error_exit "Invalid backup format"
fi

# Warning prompt
echo "WARNING: This will replace all data!"
read -p "Continue? (yes/no): " confirm
[ "$confirm" != "yes" ] && exit 0

# Optimize MySQL settings for restore
log "Optimizing MySQL settings..."
CURRENT_SETTINGS=$(mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SELECT @@sql_mode, @@foreign_key_checks, @@unique_checks, @@autocommit;" -s -N)
SQL_MODE=$(echo "$CURRENT_SETTINGS" | cut -f1)
FOREIGN_KEY_CHECKS=$(echo "$CURRENT_SETTINGS" | cut -f2)
UNIQUE_CHECKS=$(echo "$CURRENT_SETTINGS" | cut -f3)
AUTOCOMMIT=$(echo "$CURRENT_SETTINGS" | cut -f4)

mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "
SET SESSION sql_mode='NO_AUTO_VALUE_ON_ZERO';
SET FOREIGN_KEY_CHECKS=0;
SET UNIQUE_CHECKS=0;
SET AUTOCOMMIT=0;
"

# Restore backup
log "Restoring backup..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    zcat "$BACKUP_FILE" | mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" || error_exit "Restore failed"
else
    mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" < "$BACKUP_FILE" || error_exit "Restore failed"
fi

# Restore MySQL settings
mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "
SET SESSION sql_mode='$SQL_MODE';
SET FOREIGN_KEY_CHECKS=$FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=$UNIQUE_CHECKS;
SET AUTOCOMMIT=$AUTOCOMMIT;
COMMIT;
"

log "Full backup restored successfully"

# Point-in-time recovery
if [ -n "$POINT_IN_TIME" ]; then
    log "Starting point-in-time recovery to: $POINT_IN_TIME"
    
    # Extract binary log info
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        BINLOG_FILE=$(zgrep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")
        BINLOG_POS=$(zgrep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_POS=\([0-9]*\).*/\1/p")
    else
        BINLOG_FILE=$(grep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")
        BINLOG_POS=$(grep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_POS=\([0-9]*\).*/\1/p")
    fi
    
    BINLOG_DIR="/var/log/mysql"
    [ ! -d "$BINLOG_DIR" ] && error_exit "Binary log directory not found: $BINLOG_DIR"
    
    # Apply binary logs
    for binlog in $(find "$BINLOG_DIR" -name "mysql-bin.*" | sort); do
        if [[ "$binlog" > "$BINLOG_DIR/$BINLOG_FILE" ]] || [[ "$binlog" == "$BINLOG_DIR/$BINLOG_FILE" ]]; then
            log "Applying: $binlog"
            if [ "$binlog" == "$BINLOG_DIR/$BINLOG_FILE" ]; then
                mysqlbinlog --start-position="$BINLOG_POS" --stop-datetime="$POINT_IN_TIME" "$binlog" | \
                mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD"
            else
                mysqlbinlog --stop-datetime="$POINT_IN_TIME" "$binlog" | \
                mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD"
            fi
        fi
    done
    
    log "Point-in-time recovery completed"
fi

log "Restore completed successfully"