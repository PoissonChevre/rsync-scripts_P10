#!/bin/bash

# -----------------------------------------------------------------------------
# Differential Backup Script
# -----------------------------------------------------------------------------
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs a differential backup using rsync, keeping backups
# from the specified number of days and ensuring at least the two most recent
# backups are always retained.
# Usage: ./backup_diff.sh <TARGET_DIR> <RETENTION>
# Example: ./backup_diff.sh MACHINES 2
# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
#       https://explainshell.com/explain/1/rsync
#       dd if=/dev/zero of=/chemin/vers/repertoire/MACHINE/vm-1Go bs=4096 count=262144 (créé un fichier de 1Go de zéros binaires, 262144 x 4Ko)
#       dd i f=/dev/zero of=/chemin/vers/repertoire/MACHINE/vm-2Go bs=4096 count=524288 (créé un fichier de 2Go de zéros binaires, 524288 x 4Ko)
#       cat vm-1Go vm-2Go >> vm-3Go (créé un fichier de 3Go de zéros binaires)
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

# Find the last full backup or create one if there is no full backup
find_last_full_backup() {
    LAST_FULL_BACKUP=$(ssh $REMOTE "ls -d ${DST_DIR}backup_FULL_* 2>/dev/null | sort | tail -n 1")

    if [ -z "$LAST_FULL_BACKUP" ]; then
        # No existing full backup found, force the creation of a new one
        echo "No previous full backup found. Forcing the creation of a new full backup..."
        rsync "${PARAMETERS[@]}" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_FULL_${TIMESTAMP}"
        LAST_FULL_BACKUP="$REMOTE:${DST_DIR}backup_FULL_${TIMESTAMP}"
    else
        echo "Last full backup: $LAST_FULL_BACKUP"
    fi
}

# Check if the last full backup is older than the specified RETENTION
is_last_full_backup_old() {
    if [ -n "$LAST_FULL_BACKUP" ]; then
        LAST_BACKUP_TIME=$(ssh $REMOTE "stat -c %W ${LAST_FULL_BACKUP}")
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - LAST_BACKUP_TIME))
        
        if [ "$ELAPSED_TIME" -ge "$((RETENTION * 86400))" ]; then
            return 0  # Last full backup is older than RETENTION days
        else
            return 1  # Last full backup is within the RETENTION days
        fi
    fi
    
    return 0  # No last full backup found, treat as older than RETENTION days
}

# Perform a differential backup
perform_diff_backup() {
    find_last_full_backup

    if is_last_full_backup_old; then
        # Last full backup is older than RETENTION days, create a new full backup
        echo "Last full backup is older than $RETENTION days. Creating a new full backup..."
        rsync "${PARAMETERS[@]}" "$SRC_DIR" "${REMOTE}:${DST_DIR}backup_FULL_${TIMESTAMP}"

        # Remove the previous full backup
        if [ -n "$LAST_FULL_BACKUP" ]; then
            echo "Removing the previous full backup: $LAST_FULL_BACKUP"
            ssh $REMOTE "rm -rf $LAST_FULL_BACKUP"
        fi
    else
        # Differential backup using the most recent full backup as reference
        echo "Performing differential backup using the most recent full backup as reference."
        rsync "${PARAMETERS[@]}" --link-dest="$LAST_FULL_BACKUP" "$SRC_DIR" "${REMOTE}:${DST_DIR}backup_diff_${TIMESTAMP}"
    fi
}

# Clean up old backups, keeping only backups from the last N days and
# ensuring the most recent backups are retained regardless of age.
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    # Remove old backups based on RETENTION days (using ctime for directory change time)
    ssh $REMOTE "find $DST_DIR -maxdepth 1 -name 'backup_diff_*' -ctime +$RETENTION -exec rm -rf {} \;"
}

# Main execution flow
main() {
    echo "Starting backup process..."
    perform_diff_backup
    cleanup_old_backups
    echo "Backup and cleanup completed."
}

# Execute the main function
main
