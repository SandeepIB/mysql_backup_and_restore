#!/bin/bash

# MySQL Restore Script with Latest State Recovery
# Usage: ./restore_full.sh <backup_file> [latest]

set -e

# Load configuration
source "$(dirname "$0")/db_conf.conf"

BACKUP_FILE="$1"
RESTORE_MODE="$2"

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
    echo "Usage: $0 <backup_file> [latest]"
    echo "Examples:"
    echo "  $0 /backup/mysql/20240101/full_backup_20240101_120000.sql.gz"
    echo "  $0 /backup/mysql/20240101/full_backup_20240101_120000.sql.gz latest"
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
CURRENT_SETTINGS=$(mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD" -e "SELECT @@sql_mode, @@foreign_key_checks, @@unique_checks, @@autocommit;" -s -N)
SQL_MODE=$(echo "$CURRENT_SETTINGS" | cut -f1)
FOREIGN_KEY_CHECKS=$(echo "$CURRENT_SETTINGS" | cut -f2)
UNIQUE_CHECKS=$(echo "$CURRENT_SETTINGS" | cut -f3)
AUTOCOMMIT=$(echo "$CURRENT_SETTINGS" | cut -f4)

mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD" -e "
SET SESSION sql_mode='NO_AUTO_VALUE_ON_ZERO';
SET FOREIGN_KEY_CHECKS=0;
SET UNIQUE_CHECKS=0;
SET AUTOCOMMIT=0;
"

# Restore backup
log "Restoring backup to: $RESTORE_HOST:$RESTORE_PORT"
if [[ "$BACKUP_FILE" == *.gz ]]; then
    zcat "$BACKUP_FILE" | mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD" || error_exit "Restore failed"
else
    mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD" < "$BACKUP_FILE" || error_exit "Restore failed"
fi

# Restore MySQL settings
mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD" -e "
SET SESSION sql_mode='$SQL_MODE';
SET FOREIGN_KEY_CHECKS=$FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=$UNIQUE_CHECKS;
SET AUTOCOMMIT=$AUTOCOMMIT;
COMMIT;
"

log "Full backup restored successfully"

# Apply all available binary logs if 'latest' specified
if [ "$RESTORE_MODE" = "latest" ]; then
    log "Applying all available binary logs for latest state..."
    
    # Extract binary log info
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        BINLOG_FILE=$(zgrep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")
        BINLOG_POS=$(zgrep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_POS=\([0-9]*\).*/\1/p")
    else
        BINLOG_FILE=$(grep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")
        BINLOG_POS=$(grep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_POS=\([0-9]*\).*/\1/p")
    fi
    
    [ ! -d "$BINLOG_DIR" ] && error_exit "Binary log directory not found: $BINLOG_DIR"
    
    # Apply all binary logs from backup point to current
    for binlog in $(find "$BINLOG_DIR" -name "mysql-bin.*" | sort); do
        if [[ "$binlog" > "$BINLOG_DIR/$BINLOG_FILE" ]] || [[ "$binlog" == "$BINLOG_DIR/$BINLOG_FILE" ]]; then
            log "Applying: $binlog"
            if [ "$binlog" == "$BINLOG_DIR/$BINLOG_FILE" ]; then
                if [ -n "$DB" ]; then
                    mysqlbinlog --start-position="$BINLOG_POS" --database="$DB" "$binlog" | \
                    mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD"
                else
                    mysqlbinlog --start-position="$BINLOG_POS" "$binlog" | \
                    mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD"
                fi
            else
                if [ -n "$DB" ]; then
                    mysqlbinlog --database="$DB" "$binlog" | \
                    mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD"
                else
                    mysqlbinlog "$binlog" | \
                    mysql -h "$RESTORE_HOST" -P "$RESTORE_PORT" -u "$RESTORE_USER" -p"$RESTORE_PASSWORD"
                fi
            fi
        fi
    done
    
    log "Latest state recovery completed"
fi

log "Restore completed successfully"