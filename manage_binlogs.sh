#!/bin/bash

# MySQL Binary Log Management Script
# Usage: ./manage_binlogs.sh <action> [days]

set -e

# Load configuration
source "$(dirname "$0")/db_conf.conf"

ACTION="$1"
DAYS="${2:-7}"

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
if [ -z "$ACTION" ]; then
    echo "Usage: $0 <action> [days]"
    echo "Actions:"
    echo "  show     - Show current binary logs"
    echo "  purge    - Purge old binary logs (default: 7 days)"
    echo "  flush    - Flush logs (start new binlog file)"
    echo "  status   - Show master status"
    echo ""
    echo "Examples:"
    echo "  $0 show"
    echo "  $0 purge 3"
    echo "  $0 flush"
    exit 1
fi

# Verify MySQL connection
mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SELECT 1;" > /dev/null 2>&1 || error_exit "MySQL connection failed"

case "$ACTION" in
    "show")
        log "Current binary logs:"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW BINARY LOGS;"
        ;;
        
    "purge")
        log "Purging binary logs older than $DAYS days..."
        
        # Show logs before purging
        log "Binary logs before purging:"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW BINARY LOGS;"
        
        # Purge old logs
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL $DAYS DAY);"
        
        # Show logs after purging
        log "Binary logs after purging:"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW BINARY LOGS;"
        
        log "Binary log purge completed"
        ;;
        
    "flush")
        log "Flushing binary logs..."
        
        # Show current status
        log "Current master status:"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW MASTER STATUS;"
        
        # Flush logs
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "FLUSH LOGS;"
        
        # Show new status
        log "New master status:"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW MASTER STATUS;"
        
        log "Binary log flush completed"
        ;;
        
    "status")
        log "Master status:"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW MASTER STATUS;"
        
        log "Binary log configuration:"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW VARIABLES LIKE 'log_bin%';"
        mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SHOW VARIABLES LIKE 'binlog%';"
        ;;
        
    *)
        error_exit "Unknown action: $ACTION"
        ;;
esac