#!/bin/bash

# MySQL Full Backup Script with Binary Log Management
# Usage: ./backup_full.sh

set -e

# Load configuration
source "$(dirname "$0")/db_conf.conf"

# Configuration
BACKUP_BASE_DIR="/backup/mysql"
LOG_DIR="$BACKUP_BASE_DIR/logs"
DATE=$(date +%Y%m%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$DATE"
BACKUP_FILE="$BACKUP_DIR/full_backup_$TIMESTAMP.sql"
LOG_FILE="$LOG_DIR/backup_$DATE.log"

# Create directories
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

log "Starting MySQL full backup..."

# Verify MySQL connection
mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SELECT 1;" > /dev/null 2>&1 || error_exit "MySQL connection failed"

log "MySQL connection verified"

# Check available disk space
REQUIRED_SPACE=$(mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "
SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size MB' 
FROM information_schema.tables;" -s -N)

AVAILABLE_SPACE=$(df "$BACKUP_BASE_DIR" | awk 'NR==2 {print int($4/1024)}')

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    error_exit "Insufficient disk space. Required: ${REQUIRED_SPACE}MB, Available: ${AVAILABLE_SPACE}MB"
fi

log "Disk space check passed: ${AVAILABLE_SPACE}MB available"

# Take full backup
log "Creating full backup: $BACKUP_FILE"

mysqldump --single-transaction \
          --routines \
          --triggers \
          --master-data=2 \
          --flush-logs \
          --all-databases \
          -h "$HOST" \
          -P "$PORT" \
          -u "$USER" \
          -p"$PASSWORD" > "$BACKUP_FILE" || error_exit "Backup failed"

# Verify backup file
if [ ! -s "$BACKUP_FILE" ]; then
    error_exit "Backup file is empty or missing"
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup completed successfully: $BACKUP_SIZE"

# Get binary log position from backup
BINLOG_INFO=$(grep "CHANGE MASTER TO" "$BACKUP_FILE" | head -1)
log "Binary log position: $BINLOG_INFO"

# Purge old binary logs (keep 3 days)
log "Purging old binary logs..."
mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);" || log "Warning: Could not purge old binary logs"

# Show current binary logs
mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW BINARY LOGS;" >> "$LOG_FILE"

# Create backup info file
cat > "$BACKUP_DIR/backup_info.txt" << EOF
Backup Date: $(date)
Backup File: $BACKUP_FILE
Backup Size: $BACKUP_SIZE
Database: $DB
Binary Log Info: $BINLOG_INFO
EOF

log "Backup process completed successfully"
log "Backup location: $BACKUP_FILE"
log "Log file: $LOG_FILE"

# Optional: Compress backup
if command -v gzip &> /dev/null; then
    log "Compressing backup..."
    gzip "$BACKUP_FILE"
    log "Backup compressed: ${BACKUP_FILE}.gz"
fi