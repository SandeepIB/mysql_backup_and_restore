# MySQL Online Backup & Restore Solution

Complete MySQL backup strategy using full backups and binary logs for point-in-time recovery without service downtime.

## Features

- **Online Backups**: No MySQL service interruption
- **Point-in-Time Recovery**: Binary log-based incremental restore
- **Automated Scripts**: Ready-to-use shell scripts
- **Safety Checks**: Built-in validation and error handling
- **Configurable**: Easy configuration management

## Quick Start

1. **Configure Database Connection**:
   ```bash
   cp db_conf.conf.example db_conf.conf
   # Edit db_conf.conf with your MySQL credentials
   ```

2. **Run Full Backup**:
   ```bash
   ./backup_full.sh
   ```

3. **Setup Automated Backups**:
   ```bash
   ./setup_cron.sh
   ```

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `backup_full.sh` | Creates full MySQL backup with binlog management |
| `restore_full.sh` | Restores full backup with point-in-time recovery |
| `manage_binlogs.sh` | Manages binary log purging and rotation |
| `setup_cron.sh` | Sets up automated backup scheduling |
| `verify_backup.sh` | Validates backup integrity |

## Configuration

Edit `db_conf.conf`:
```
PORT=3307
HOST=127.0.0.1
USER=phpmyadmin
PASSWORD=StrongPasswordHere!
DB=icc_store_Sep23
```

## Usage Examples

### Full Backup
```bash
./backup_full.sh
```

### Restore to Specific Time
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql "2024-01-01 15:30:00"
```

### Manual Binlog Management
```bash
./manage_binlogs.sh purge 3  # Keep 3 days of logs
./manage_binlogs.sh flush    # Start new binlog file
```

## Directory Structure

```
/backup/mysql/
├── YYYYMMDD/
│   ├── full_backup_YYYYMMDD_HHMMSS.sql
│   └── backup.log
└── logs/
    └── backup_YYYYMMDD.log
```

## Prerequisites

- MySQL/MariaDB with binary logging enabled
- User with RELOAD, LOCK TABLES, REPLICATION CLIENT privileges
- Sufficient disk space (recommend 2x database size)
- Root/sudo access for cron setup

## Required MySQL Configuration

Add to `/etc/mysql/my.cnf`:
```ini
[mysqld]
log-bin = /var/log/mysql/mysql-bin
server-id = 1
binlog-format = ROW
expire_logs_days = 7
max_binlog_size = 100M
```

## Safety & Best Practices

- Test restore procedures regularly
- Monitor disk space usage
- Verify backup integrity before purging logs
- Keep multiple backup generations
- Document recovery procedures

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure backup directory is writable
2. **MySQL Connection Failed**: Check credentials in db_conf.conf
3. **Insufficient Space**: Monitor disk usage before backups
4. **Binlog Not Found**: Verify binary logging is enabled

### Log Files

- Backup logs: `/backup/mysql/logs/`
- MySQL error log: `/var/log/mysql/error.log`
- Binary logs: `/var/log/mysql/mysql-bin.*`

## Support

For issues or questions, check the log files and verify MySQL configuration.