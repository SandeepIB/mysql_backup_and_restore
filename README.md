# MySQL Backup & Restore - Minimal Testing Version

## Quick Setup

1. **Configure database**:
   ```bash
   cp db_conf.conf.example db_conf.conf
   # Edit with your MySQL credentials
   ```

2. **Create backup directory**:
   ```bash
   sudo mkdir -p /backup/mysql
   sudo chmod 755 /backup/mysql
   ```

## Usage

### Full Backup (Compressed)
```bash
./backup_full.sh
```

### Restore Full Backup
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql.gz
```

### Point-in-Time Restore
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql.gz "2024-01-01 15:30:00"
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
- ✅ **Optimized restore** - Disables checks during import
- ✅ **Error handling** - Comprehensive validation

## Files

- `backup_full.sh` - Main backup script with safe binlog purging
- `restore_full.sh` - Restore with point-in-time recovery
- `db_conf.conf` - Database configuration
- `README.md` - This documentation

## Prerequisites

- MySQL with binary logging enabled
- User with RELOAD, LOCK TABLES, REPLICATION CLIENT privileges
- `/backup/mysql` directory with write permissions

## MySQL Configuration Required

Add to `/etc/mysql/my.cnf`:
```ini
[mysqld]
log-bin = /var/log/mysql/mysql-bin
server-id = 1
binlog-format = ROW
```

## Safety Features

- **Safe purging**: Only removes logs before backup point
- **Backup verification**: Validates file format before restore
- **Session optimization**: Temporarily disables checks for faster restore
- **Confirmation prompts**: Prevents accidental data loss