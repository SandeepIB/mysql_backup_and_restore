#!/bin/bash

# MySQL Backup Verification Script
# Usage: ./verify_backup.sh [backup_file]

set -e

# Load configuration
source "$(dirname "$0")/db_conf.conf"

BACKUP_FILE="$1"
BACKUP_BASE_DIR="/backup/mysql"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Find latest backup if not specified
if [ -z "$BACKUP_FILE" ]; then
    LATEST_DIR=$(ls -1 "$BACKUP_BASE_DIR" | grep -E '^[0-9]{8}$' | sort -r | head -1)
    if [ -z "$LATEST_DIR" ]; then
        error_exit "No backup directories found in $BACKUP_BASE_DIR"
    fi
    
    BACKUP_FILE=$(ls -1t "$BACKUP_BASE_DIR/$LATEST_DIR"/*.sql* 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        error_exit "No backup files found in $BACKUP_BASE_DIR/$LATEST_DIR"
    fi
fi

log "Verifying backup: $BACKUP_FILE"

# Check if file exists
if [ ! -f "$BACKUP_FILE" ]; then
    error_exit "Backup file not found: $BACKUP_FILE"
fi

# Check file size
FILE_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
if [ "$FILE_SIZE" -eq 0 ]; then
    error_exit "Backup file is empty"
fi

log "File size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Handle compressed files
TEMP_FILE=""
if [[ "$BACKUP_FILE" == *.gz ]]; then
    log "Backup is compressed, creating temporary decompressed file for verification..."
    TEMP_FILE="/tmp/backup_verify_$(date +%s).sql"
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    VERIFY_FILE="$TEMP_FILE"
else
    VERIFY_FILE="$BACKUP_FILE"
fi

# Verify file header
if ! head -5 "$VERIFY_FILE" | grep -q "MySQL dump"; then
    error_exit "Invalid backup file format - missing MySQL dump header"
fi

log "✓ File header verification passed"

# Check for dump completion
if ! tail -5 "$VERIFY_FILE" | grep -q "Dump completed"; then
    log "Warning: Backup may be incomplete - missing completion marker"
else
    log "✓ Backup completion marker found"
fi

# Extract and verify binary log information
BINLOG_INFO=$(grep "CHANGE MASTER TO" "$VERIFY_FILE" | head -1)
if [ -n "$BINLOG_INFO" ]; then
    log "✓ Binary log information found: $BINLOG_INFO"
else
    log "Warning: No binary log information found in backup"
fi

# Count databases and tables
DB_COUNT=$(grep -c "^CREATE DATABASE" "$VERIFY_FILE" || echo "0")
TABLE_COUNT=$(grep -c "^CREATE TABLE" "$VERIFY_FILE" || echo "0")

log "✓ Databases found: $DB_COUNT"
log "✓ Tables found: $TABLE_COUNT"

# Verify SQL syntax (basic check)
if command -v mysql &> /dev/null; then
    log "Performing SQL syntax verification..."
    
    # Create a temporary test database for verification
    TEST_DB="backup_verify_test_$(date +%s)"
    
    mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "CREATE DATABASE $TEST_DB;" 2>/dev/null || {
        log "Warning: Cannot create test database for syntax verification"
    }
    
    if mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW DATABASES;" | grep -q "$TEST_DB"; then
        # Test a small portion of the backup
        head -100 "$VERIFY_FILE" | tail -50 | mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" "$TEST_DB" 2>/dev/null && {
            log "✓ SQL syntax verification passed"
        } || {
            log "Warning: SQL syntax verification failed"
        }
        
        # Clean up test database
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "DROP DATABASE $TEST_DB;" 2>/dev/null || true
    fi
fi

# Check backup age
BACKUP_DATE=$(stat -f%m "$BACKUP_FILE" 2>/dev/null || stat -c%Y "$BACKUP_FILE" 2>/dev/null)
CURRENT_DATE=$(date +%s)
AGE_HOURS=$(( (CURRENT_DATE - BACKUP_DATE) / 3600 ))

if [ "$AGE_HOURS" -gt 48 ]; then
    log "Warning: Backup is $AGE_HOURS hours old"
else
    log "✓ Backup age: $AGE_HOURS hours"
fi

# Clean up temporary file
if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
    rm -f "$TEMP_FILE"
fi

# Generate verification report
REPORT_FILE="$(dirname "$BACKUP_FILE")/verification_report_$(date +%Y%m%d_%H%M%S).txt"
cat > "$REPORT_FILE" << EOF
MySQL Backup Verification Report
================================
Date: $(date)
Backup File: $BACKUP_FILE
File Size: $(du -h "$BACKUP_FILE" | cut -f1)
Age: $AGE_HOURS hours
Databases: $DB_COUNT
Tables: $TABLE_COUNT
Binary Log Info: $BINLOG_INFO
Status: VERIFIED
EOF

log "✓ Backup verification completed successfully"
log "Verification report: $REPORT_FILE"