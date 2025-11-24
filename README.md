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
# DB=database_name  # Specify single database or leave empty for all databases
DB=

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

### Full Restore (Complete Backup Only)
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql.gz
```

### Latest State Restore (Backup + All Available Binary Logs)
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql.gz latest
```

## Restore Options

| Mode | Command | Description |
|------|---------|-------------|
| **Backup Only** | `./restore_full.sh backup.sql.gz` | Restores to exact backup point |
| **Latest State** | `./restore_full.sh backup.sql.gz latest` | Restores backup + all binary logs |

## Features

- ✅ **Online backups** - No MySQL downtime
- ✅ **Compressed backups** - Direct .sql.gz creation
- ✅ **Safe binary log purging** - Preserves logs after backup point
- ✅ **Latest state recovery** - Restore + all available binary logs
- ✅ **Single or all database backup** - Flexible database selection
- ✅ **Filtered binary logs** - Database-specific log filtering
- ✅ **Separate restore credentials** - Backup and restore to different servers
- ✅ **Configurable paths** - Custom backup and binary log directories
- ✅ **Optimized restore** - Disables checks during import
- ✅ **Error handling** - Comprehensive validation

## Files

- `backup_full.sh` - Main backup script with safe binlog purging
- `restore_full.sh` - Restore with latest state recovery
- `db_conf.conf` - Database configuration
- `README.md` - This documentation

## Prerequisites

- MySQL with binary logging enabled
- Source user with RELOAD, LOCK TABLES, REPLICATION CLIENT privileges
- Restore user with appropriate privileges for target database
- Configured backup directory with write permissions
- Access to binary log directory for latest state recovery

## MySQL Configuration Required

Add to `/etc/mysql/my.cnf`:
```ini
[mysqld]
log-bin = /var/log/mysql/mysql-bin
server-id = 1
binlog-format = ROW
```

## Use Cases

### Disaster Recovery
```bash
# Use 'latest' option for most current state
./restore_full.sh backup_file.sql.gz latest
```

### Single Database Backup
```bash
# Set DB=database_name in config
./backup_full.sh  # Only backs up specified database
./restore_full.sh backup_file.sql.gz latest  # Only restores that database
```

### All Databases Backup
```bash
# Set DB= (empty) in config
./backup_full.sh  # Backs up all databases
./restore_full.sh backup_file.sql.gz latest  # Restores all databases
```

### Production to Staging
```bash
# Backup from production, restore to staging
./backup_full.sh
./restore_full.sh backup_file.sql.gz latest
```

## Automated Backup Setup

### Setup Weekly Full Backup with Cron

1. **Edit crontab**:
   ```bash
   crontab -e
   ```

2. **Add weekly full backup** (every Sunday at 2 AM):
   ```bash
   0 2 * * 0 /path/to/backup_full.sh >> /var/log/mysql_backup.log 2>&1
   ```

3. **Create log file**:
   ```bash
   sudo touch /var/log/mysql_backup.log
   sudo chmod 644 /var/log/mysql_backup.log
   ```

### Recovery Strategy

- **Full backup**: Created weekly (7 days)
- **Binary logs**: Accumulated between full backups
- **Recovery**: Use latest restore to get most current state

```bash
# Restore latest full backup + all binary logs since backup
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_020000.sql.gz latest
```

### Backup Schedule Example

```
Sunday    -> Full Backup (backup_full.sh)
Monday    -> Binary logs only
Tuesday   -> Binary logs only
Wednesday -> Binary logs only
Thursday  -> Binary logs only
Friday    -> Binary logs only
Saturday  -> Binary logs only
Sunday    -> Full Backup (backup_full.sh) + purge old logs
```

## Safety Features

- **Safe purging**: Only removes logs before backup point
- **Backup verification**: Validates file format before restore
- **Session optimization**: Temporarily disables checks for faster restore
- **Confirmation prompts**: Prevents accidental data loss
- **Separate credentials**: Isolate backup and restore operations