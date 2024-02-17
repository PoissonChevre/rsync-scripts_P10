#!/bin/bash

# https://explainshell.com/explain/1/rsync


# Configuration
SOURCE="~/MACHINES"
DESTINATION="rsync_adm@backup-srv:~/backup_storage/MACHINES/"
DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u) # Monday = 1, Sunday = 7

# Backup directories
FULL_BACKUP_DIR="full-${DATE}"
INCREMENTAL_BACKUP_DIR="incr-${DATE}"

# Perform a full backup on Saturday
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    echo "Creating a full backup in $FULL_BACKUP_DIR"
    rsync -av -e ssh $SOURCE $DESTINATION$FULL_BACKUP_DIR

# Perform incremental backups from Monday to Saturday
elif [ "$DAY_OF_WEEK" -ne 7 ]; then
    # Find the last full backup directory
    LAST_FULL_BACKUP=$(ssh rsync_adm@backup-srv "ls -d ~/backup_storage/full-* 2>/dev/null | tail -n 1")
    LAST_FULL_BACKUP=$(basename "$LAST_FULL_BACKUP")

    # If no full backup is found (unlikely scenario), exit with an error
    if [ -z "$LAST_FULL_BACKUP" ]; then
        echo "Error: No full backup found."
        exit 1
    fi

    echo "Creating an incremental backup based on $LAST_FULL_BACKUP in $INCREMENTAL_BACKUP_DIR"
    rsync -av --delete -e ssh --link-dest=$DESTINATION$LAST_FULL_BACKUP $SOURCE $DESTINATION$INCREMENTAL_BACKUP_DIR
else
    echo "No backup scheduled for Sunday."
fi

# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
