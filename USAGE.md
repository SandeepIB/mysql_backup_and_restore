# Quick Usage Guide

## Initial Setup

1. **Run setup script**:
   ```bash
   ./setup.sh
   ```

2. **Configure database connection** (if needed):
   ```bash
   nano db_conf.conf
   ```

## Daily Operations

### Take Full Backup
```bash
./backup_full.sh
```

### Verify Latest Backup
```bash
./verify_backup.sh
```

### Check Binary Logs
```bash
./manage_binlogs.sh show
```

### Clean Old Binary Logs
```bash
./manage_binlogs.sh purge 7  # Keep 7 days
```

## Recovery Operations

### Full Restore
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql
```

### Point-in-Time Restore
```bash
./restore_full.sh /backup/mysql/20240101/full_backup_20240101_120000.sql "2024-01-01 15:30:00"
```

## Automation

### Setup Automated Backups
```bash
./setup_cron.sh
```

### Check Cron Jobs
```bash
crontab -l
```

## Monitoring

### Check Backup Logs
```bash
tail -f /backup/mysql/logs/backup_$(date +%Y%m%d).log
```

### Check Cron Logs
```bash
tail -f /var/log/mysql_backup_cron.log
```

## Troubleshooting

### Test MySQL Connection
```bash
source db_conf.conf
mysql -h $HOST -P $PORT -u $USER -p$PASSWORD -e "SELECT 1;"
```

### Check Disk Space
```bash
df -h /backup/mysql
```

### Verify Binary Logging
```bash
./manage_binlogs.sh status
```