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
SRC_DIR="/home/rsync_adm/$TARGET_DIR/"
DST_DIR="/home/rsync_adm/backup_storage/$TARGET_DIR/"
REMOTE="rsync_adm@backup-srv" # USER=rsync_adm
TIMESTAMP=$(date +%Y%m%d_%H%M)
PARAMETERS=(
    -a              # --archive, equivalent to -rlptgoD (--recursive;--links;--perms;--times;--group;--owner;equivalent to --devices & --specials)
    -v              # --verbose
 #   -q             # --quiet (better with cron) ==> verbose mode for the demo
    -P              # equivalent to --partial --progress
    -e ssh          # ssh remote
    --bwlimit=50000 # KBPS ==> bandwith max 50 mb/s
    --log-file=/var/log/rsync/diff_backup.log # path to the log file
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

# Clean up all differenctial backups
cleanup_old_diff_backups() {
    echo "Cleaning up old diffential backups..."
    ssh $REMOTE "find $DST_DIR -maxdepth 1 -name 'backup_diff*'  -exec rm -rf {} \;"
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
perform_diff_backup() {

    if is_full_backup_existing; then
        if is_last_full_backup_old; then
            # Last full backup is older than RETENTION days, create a new full backup
            echo "Last full backup is older than $RETENTION days." 
            perform_full_backup
            cleanup_old_full_backups
            cleanup_old_diff_backups
        else
            cleanup_old_diff_backups
            # Differential backup using the most recent full backup as reference
            echo "Performing differential backup using the most recent full backup as reference."
            rsync "${PARAMETERS[@]}" --link-dest="$LAST_FULL_BACKUP" "$SRC_DIR" "$REMOTE:${DST_DIR}backup_diff_${TIMESTAMP}"
         fi
    else
        #  No existing full backup found, forcing the creation of a new one
        echo "Forcing the creation of a new full backup..."
        perform_full_backup
        cleanup_old_diff_backups
    fi
}

# Main execution flow
main() {
    echo "Starting backup process..."
    perform_diff_backup
    echo "Backup and cleanup completed."
}

# Execute the main function
main

