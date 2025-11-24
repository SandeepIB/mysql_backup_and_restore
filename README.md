# MySQL Backup & Restore - Minimal Testing Version

## Quick Setup

1. **Configure database**:
   ```bash
   cp db_conf.conf.example db_conf.conf
   # Edit with your MySQL credentials and paths
   ```

2. **Create backup directory** (or use your configured path):
   ```bash
   sudo mkdir -p /backup/mysql
   sudo chmod 755 /backup/mysql
   ```

## Configuration

### Database Settings
```bash
# Source Database (for backup)
PORT=3307
HOST=127.0.0.1
USER=phpmyadmin
PASSWORD=StrongPasswordHere!

# Restore Database (can be different server)
RESTORE_PORT=3306
RESTORE_HOST=127.0.0.1
RESTORE_USER=root
RESTORE_PASSWORD=RestorePasswordHere!

# Directory Configuration
BACKUP_BASE_DIR=/backup/mysql
BINLOG_DIR=/var/log/mysql
```

## Usage

### Full Backup (Compressed)
```bash
./backup_full.sh
```

### Full Restore (Complete Backup)
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql.gz
```

### Point-in-Time Restore (Backup + Binary Logs)
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql.gz "2024-01-01 15:30:00"
```

### Latest State Restore (Backup + All Available Binary Logs)
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql.gz latest
```

### Binary Log Management (Manual)
```bash
# Show current logs
mysql -u user -p -e "SHOW BINARY LOGS;"

# Show master status
mysql -u user -p -e "SHOW MASTER STATUS;"

# Flush logs (create new binlog file)
mysql -u user -p -e "FLUSH LOGS;"
```

## Features

- ✅ **Online backups** - No MySQL downtime
- ✅ **Compressed backups** - Direct .sql.gz creation
- ✅ **Safe binary log purging** - Preserves logs after backup point
- ✅ **Point-in-time recovery** - Precise recovery using binary logs
- ✅ **Latest state recovery** - Restore + all available binary logs
- ✅ **Separate restore credentials** - Backup and restore to different servers
- ✅ **Configurable paths** - Custom backup and binary log directories
- ✅ **Optimized restore** - Disables checks during import
- ✅ **Error handling** - Comprehensive validation

## Files

- `backup_full.sh` - Main backup script with safe binlog purging
- `restore_full.sh` - Restore with point-in-time recovery
- `db_conf.conf` - Database configuration
- `README.md` - This documentation

## Prerequisites

- MySQL with binary logging enabled
- Source user with RELOAD, LOCK TABLES, REPLICATION CLIENT privileges
- Restore user with appropriate privileges for target database
- Configured backup directory with write permissions
- Access to binary log directory for point-in-time recovery

## MySQL Configuration Required

Add to `/etc/mysql/my.cnf`:
```ini
[mysqld]
log-bin = /var/log/mysql/mysql-bin
server-id = 1
binlog-format = ROW
```

## Use Cases

### Production to Staging
```bash
# Backup from production (port 3307)
# Restore to staging (port 3306)
```

### Server Migration
```bash
# Backup from old server
# Restore to new server with different credentials
```

### Disaster Recovery
```bash
# Use 'latest' option for most current state
./restore_full.sh backup_file.sql.gz latest
```

## Safety Features

- **Safe purging**: Only removes logs before backup point
- **Backup verification**: Validates file format before restore
- **Session optimization**: Temporarily disables checks for faster restore
- **Confirmation prompts**: Prevents accidental data loss
- **Separate credentials**: Isolate backup and restore operations