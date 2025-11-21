#!/bin/bash

# MySQL Full Restore Script with Point-in-Time Recovery
# Usage: ./restore_full.sh <backup_file> [point_in_time]

set -e

# Load configuration
source "$(dirname "$0")/db_conf.conf"

# Parameters
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
    echo "Example: $0 /backup/mysql/20240101/full_backup_20240101_120000.sql"
    echo "Example: $0 /backup/mysql/20240101/full_backup_20240101_120000.sql '2024-01-01 15:30:00'"
    exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    # Check for compressed version
    if [ -f "${BACKUP_FILE}.gz" ]; then
        log "Found compressed backup, decompressing..."
        gunzip "${BACKUP_FILE}.gz"
    else
        error_exit "Backup file not found: $BACKUP_FILE"
    fi
fi

log "Starting MySQL restore process..."
log "Backup file: $BACKUP_FILE"

# Verify backup file integrity
if ! head -5 "$BACKUP_FILE" | grep -q "MySQL dump"; then
    error_exit "Invalid backup file format"
fi

# Warning prompt
echo "WARNING: This will replace all data in the MySQL server!"
echo "Database: $DB"
echo "Host: $HOST:$PORT"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log "Restore cancelled by user"
    exit 0
fi

# Stop MySQL service (optional, comment out if you want to keep it running)
# log "Stopping MySQL service..."
# sudo systemctl stop mysql

log "Restoring full backup..."

# Restore the full backup
mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" < "$BACKUP_FILE" || error_exit "Full backup restore failed"

log "Full backup restored successfully"

# Point-in-time recovery using binary logs
if [ -n "$POINT_IN_TIME" ]; then
    log "Starting point-in-time recovery to: $POINT_IN_TIME"
    
    # Extract binary log position from backup file
    BINLOG_FILE=$(grep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")
    BINLOG_POS=$(grep "CHANGE MASTER TO" "$BACKUP_FILE" | sed -n "s/.*MASTER_LOG_POS=\([0-9]*\).*/\1/p")
    
    log "Starting from binary log: $BINLOG_FILE, position: $BINLOG_POS"
    
    # Find binary log files to apply
    BINLOG_DIR="/var/log/mysql"
    
    if [ ! -d "$BINLOG_DIR" ]; then
        error_exit "Binary log directory not found: $BINLOG_DIR"
    fi
    
    # Apply binary logs
    for binlog in $(ls "$BINLOG_DIR"/mysql-bin.* | sort); do
        if [[ "$binlog" > "$BINLOG_DIR/$BINLOG_FILE" ]] || [[ "$binlog" == "$BINLOG_DIR/$BINLOG_FILE" ]]; then
            log "Applying binary log: $binlog"
            
            if [ "$binlog" == "$BINLOG_DIR/$BINLOG_FILE" ]; then
                # First log file, start from specific position
                mysqlbinlog --start-position="$BINLOG_POS" \
                           --stop-datetime="$POINT_IN_TIME" \
                           "$binlog" | \
                mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" || log "Warning: Error applying $binlog"
            else
                # Subsequent log files, apply from beginning
                mysqlbinlog --stop-datetime="$POINT_IN_TIME" \
                           "$binlog" | \
                mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" || log "Warning: Error applying $binlog"
            fi
        fi
    done
    
    log "Point-in-time recovery completed"
fi

# Start MySQL service (if it was stopped)
# log "Starting MySQL service..."
# sudo systemctl start mysql

# Verify restore
log "Verifying restore..."
TABLES_COUNT=$(mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys');" -s -N)

log "Restore verification: $TABLES_COUNT tables found"

log "Restore process completed successfully"
log "Please verify your data and test your application"