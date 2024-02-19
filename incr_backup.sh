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
# Example: ./backup_script.sh TARGET_DIR 7
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
TIMESTAMP=$(date +%Y%m%d_%H:%M)
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
    # Update the modification date of the backup directory immediately after its creation
#    ssh $REMOTE "touch '${DST_DIR}backup_incr_${TIMESTAMP}/'"
}

# Clean up old backups, keeping only backups from the last N days and
# ensuring the two most recent backups are retained regardless of age.
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    # Extract timestamp from the directory name (backup_incr_YYYYMMDD_HH:MM)
    CURRENT_TIMESTAMP=$(date +%Y%m%d_%H:%M)
    
    # Remove old backups (full and incremental) based on RETENTION days
    ssh $REMOTE "find ${DST_DIR} -maxdepth 1 -type d -name 'backup_incr_*' -exec bash -c '
        process_old_backup \"{}\"
    ' \;"
}

# Function to process each old backup directory
process_old_backup() {
    local TIMESTAMP=$(basename "$1" | cut -d_ -f3-)

    # Check if the timestamp of the backup is older than the current timestamp
    if [ "$(date -d"$TIMESTAMP" +%s)" -lt "$(date -d"$CURRENT_TIMESTAMP" +%s)" ]; then
        # If true, remove the old backup directory
        rm -rf "$1"
        echo "Removed old backup: $1"
    else
        echo "Retaining recent backup: $1"
    fi
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
