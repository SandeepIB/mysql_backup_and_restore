#!/bin/bash

# MySQL Full Backup Script with Safe Binary Log Management
# Usage: ./backup_full.sh

set -e

# Load configuration
source "$(dirname "$0")/db_conf.conf"

# Configuration
BACKUP_BASE_DIR="/backup/mysql"
DATE=$(date +%Y%m%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$DATE"
BACKUP_FILE="$BACKUP_DIR/full_backup_$TIMESTAMP.sql.gz"

# Create directories
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

log "Starting MySQL full backup..."

# Verify MySQL connection
mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SELECT 1;" > /dev/null 2>&1 || error_exit "MySQL connection failed"

# Take compressed backup
log "Creating compressed backup: $BACKUP_FILE"
mysqldump --single-transaction \
          --routines \
          --triggers \
          --master-data=2 \
          --flush-logs \
          --all-databases \
          -h "$HOST" \
          -P "$PORT" \
          -u "$USER" \
          -p"$PASSWORD" | gzip > "$BACKUP_FILE" || error_exit "Backup failed"

# Verify backup file
if [ ! -s "$BACKUP_FILE" ]; then
    error_exit "Backup file is empty or missing"
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup completed: $BACKUP_SIZE"

# Get binary log position and safely purge old logs
BINLOG_INFO=$(zgrep "CHANGE MASTER TO" "$BACKUP_FILE" | head -1)
BACKUP_BINLOG_FILE=$(echo "$BINLOG_INFO" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")

if [ -n "$BACKUP_BINLOG_FILE" ]; then
    log "Safely purging logs before: $BACKUP_BINLOG_FILE"
    mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "PURGE BINARY LOGS TO '$BACKUP_BINLOG_FILE';" || log "Warning: Could not purge logs"
fi

log "Backup completed: $BACKUP_FILE"