#!/bin/bash

# -----------------------------------------------------------------------------
# Incremental Backup Script
# -----------------------------------------------------------------------------
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs an incremental backup using rsync, keeping backups
# from the specified number of days and ensuring the most recent
# backups are always retained.
# Usage: ./backup_script.sh <TARGET_DIR> <DAY_FULL_BACKUP> <RETENTION> 
# Example: ./backup_script.sh TICKETS 7 7
# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
#       https://explainshell.com/explain/1/rsync
# GITHUB: https://github.com/PoissonChevre/rsync-scripts_P10
# -----------------------------------------------------------------------------

# Check for required arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <TARGET_DIR> <DAY_FULL_BACKUP> <RETENTION> "
    exit 1
fi

# Assign arguments to variables
TARGET_DIR="$1"
# Day of the week for the full backup Mon=1 ==> Sun=7
DAY_FULL_BACKUP="$2"
RETENTION="$3"
# TARGET_DIR FICHIERS | MAILS | MACHINES | RH | SITE | TICkETS
SRC_DIR="/home/rsync_adm/$TARGET_DIR/"
DST_DIR="/home/rsync_adm/backup_storage/$TARGET_DIR/"
REMOTE="rsync_adm@backup-srv" 
TIMESTAMP=$(date +%Y%m%d_%H%M)
PARAMETERS=(
    -a              # --archive, equivalent to -rlptgoD (--recursive;--links;--perms;--times;--group;--owner;equivalent to --devices & --specials)
    -v              # --verbose
    -P              # equivalent to --partial --progress
    -e ssh          # ssh remote
    --log-file=/var/log/rsync/incr_backup.log # path to the log file
 #   -q             # --quiet (better with cron) ==> verbose mode for the demo
)

# Find the last full backup or will create one if there is no full backup found
is_full_backup_existing() {
    LAST_FULL_BACKUP=$(ssh $REMOTE "ls -d ${DST_DIR}backup_FULL_* 2>/dev/null | sort | tail -n 1")
    if [ -n "$LAST_FULL_BACKUP" ]; then
        # Display last full backup path
        echo "Last full backup: $LAST_FULL_BACKUP"
        return 0 # 0 = true
    else
        # No existing full backup found, we will force the creation of one
        echo "No previous full backup found."
        return 1 # 1 = false
    fi
}

# Check if the last full backup is older than the specified RETENTION (return boolean)
is_last_full_backup_old() {
    CURRENT_TIME=$(date +%s)
    LAST_BACKUP_TIME=$(ssh $REMOTE "stat -c %W $LAST_FULL_BACKUP")
    ELAPSED_TIME=$((CURRENT_TIME - LAST_BACKUP_TIME))
    # Converting RETENTION in seconds ==> one day =24*3600s=86400s
    RETENTION_IN_SECONDS=$((RETENTION * 86400))
    if [ "$ELAPSED_TIME" -ge "$RETENTION_IN_SECONDS" ]; then 
        # Last full backup is older than RETENTION days 
        return 0  # 0 = true
    else
        # Last full backup is within the RETENTION days
        return 1  # 1 = false
    fi
}

# Find the most recent backup (using mtime for directory change time), create less than 1620 minutes (27 heures)
is_last_backup() {
    LAST_BACKUP=$(ssh $REMOTE "find $DST_DIR -maxdepth 1 -name 'backup_*' -cmin -100;")
    if [ -n "$LAST_FULL_BACKUP" ]; then
        # Display last backup path
        echo "Last backup: $LAST_BACKUP"
        return 0 # 0 = true
        # No backup found
        echo "No previous backup found."
        return 1 # 1 = false
    fi
}

# Clean up old incremental backups
cleanup_old_incr_backups() {
    echo "Cleaning up old incremental backups..."
    ssh $REMOTE "find $DST_DIR -maxdepth 1 -name 'backup_incr*' -exec rm -rf {} \;"
}

# Clean up old FULL backups
cleanup_old_full_backups() {
    echo "Cleaning up old full backups..."
    # Remove old backups  based on RETENTION days (using ctime for directory change time)
    ssh $REMOTE "find $DST_DIR -maxdepth 1 -name 'backup_FULL*' -ctime +$RETENTION -exec rm -rf {} \;"
}

# Perform a full backup
perform_full_backup() {
    echo "Creating a new full backup..."
    rsync "${PARAMETERS[@]}" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_FULL_${TIMESTAMP}"
    # Call the fct to display the directory path of the new full backup 
    is_full_backup_existing
 }

# Perform a differential backup
perform_incr_backup() {
    if is_full_backup_existing; then
        # Last full backup is older than RETENTION days and  today is DAY_FULL_BACKUP, create a new full backup
        if is_last_full_backup_old && [ "$(date +%u)" -eq $DAY_FULL_BACKUP ]; then
            echo "Last full backup is older than $RETENTION days." 
            perform_full_backup
            cleanup_old_full_backups
            cleanup_old_incr_backups
        else
            # Incremental backup using the most recent backup as reference
            is_last_backup
            echo "Performing incremental backup using the most recent backup as reference."
            rsync "${PARAMETERS[@]}" --link-dest="$LAST_BACKUP" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_incr_${TIMESTAMP}"
         fi
    else
        #  No existing full backup found, forcing the creation of a new one
        echo "Forcing the creation of a new full backup..."
        perform_full_backup
        cleanup_old_incr_backups
    fi
}

# Main execution flow
main() {
    echo "Starting backup process..."
    perform_incr_backup
    echo "Backup and cleanup completed."
}

# Execute the main function
main

