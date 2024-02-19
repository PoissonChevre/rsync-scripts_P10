#!/bin/bash

# -----------------------------------------------------------------------------
# Incremental Backup Script
# -----------------------------------------------------------------------------
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs an incremental backup using rsync, keeping backups
# from the specified number of days and ensuring at least the two most recent
# backups are always retained.
# Usage: ./backup_script.sh <TARGET_DIR> <RETENTION>
# Example: ./backup_script.sh TICKETS 7
# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
#       https://explainshell.com/explain/1/rsync
# -----------------------------------------------------------------------------

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <TARGET_DIR> <RETENTION>"
    exit 1
fi

# Assign arguments to variables
TARGET_DIR="$1"
RETENTION="$2"
SRC_DIR="/home/$USER/$TARGET_DIR/"
DST_DIR="/home/$USER/backup_storage/$TARGET_DIR/"
REMOTE="$USER@backup-srv"
TIMESTAMP=$(date +%Y%m%d_%H%M)
PARAMETERS=(
    -a      # --archive, equivalent to -rlptgoD (--recursive;--links;--perms;--times;--group;--owner;equivalent to --devices & --specials)
    -v      # --verbose
    -P      # equivalent to --partial --progress
    -e ssh  # ssh remote
)

# Find the last backup
find_last_backup() {
    LAST_BACKUP=$(ssh $REMOTE "ls -d ${DST_DIR}backup_incr_* 2>/dev/null | tail -n 1")
    echo "Last backup: $LAST_BACKUP"
}

# Perform an incremental backup
perform_incr_backup() {
    find_last_backup
    # If a previous backup is found, perform an incremental backup
    if [ -n "$LAST_BACKUP" ]; then
        echo "Performing incremental backup..."
        rsync "${PARAMETERS[@]}" --link-dest "$LAST_BACKUP" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_incr_${TIMESTAMP}"
    else
        # If no previous incremental backup is found, perform a full backup
        echo "No previous incremental backup found. Performing a full backup..."
        rsync "${PARAMETERS[@]}" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_incr_${TIMESTAMP}"
    fi
}

# Clean up old backups, keeping only backups from the last N days and
# ensuring the two most recent backups are retained regardless of age.
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    # Remove old backups  based on RETENTION days (using ctime for directory change time)
    ssh $REMOTE "find $DST_DIR -maxdepth 1 -type d -name 'backup_incr_*' -ctime +$RETENTION -exec rm -rf {} \;"
}

# Main execution flow
main() {
    echo "Starting backup process..."
    perform_incr_backup
    cleanup_old_backups
    echo "Backup and cleanup completed."
}

# Execute the main function
main
