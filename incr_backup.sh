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
 #   -q     # --quiet (better with cron) ==> verbose mode for the demo
    -P      # equivalent to --partial --progress
    -e ssh  # ssh remote
    --log-file=/var/log/rsync/incr_backup.log # path to the log file
)

# Find the last  backup or will create one if there is no  backup found
is_backup_existing() {

    LAST_INCR_BACKUP=$(ssh $REMOTE "ls -d ${DST_DIR}backup_incr_* 2>/dev/null | sort | tail -n 1")

    if [ -n "$LAST_INCR_BACKUP" ]; then
        # Display last  backup path
        echo "Last incremental backup: $LAST_INCR_BACKUP"
        return 0 # 0 = true
    else
        # No existing full backup found, we will force the creation of one
        echo "No previous backup found."
        return 1 # 1 = false
    fi
}

perform_full_backup() {

    echo "Creating a new full backup..."
    rsync "${PARAMETERS[@]}" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_FULL_${TIMESTAMP}"
    # Call the fct to display the directory path of the new full backup 
    is_backup_existing
 }

# Perform an incremental backup
perform_incr_backup() {

    if is_backup_existing; then
            # Differential backup using the most recent backup as reference
            echo "Performing incremental backup using the most recent backup as reference."
            rsync "${PARAMETERS[@]}" --link-dest="$LAST_INCR_BACKUP" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_diff_${TIMESTAMP}"
         fi
    else
        #  No existing full backup found, forcing the creation of a new one
        echo "Forcing the creation of a new full backup..."
        perform_full_backup
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
