#!/bin/bash

# https://explainshell.com/explsain/1/rsync


# Configuration
SOURCE="/path/to/source/"
DESTINATION="rsync_adm@backup-srv:~/backup_storage/"
DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u) # Monday = 1, Sunday = 7

# Backup directories
FULL_BACKUP_DIR="full-${DATE}"
DIFFERENTIAL_BACKUP_DIR="diff-${DATE}"

# Perform a full backup on Saturday
if [ "$DAY_OF_WEEK" -eq 6 ]; then
    echo "Creating a full backup in $FULL_BACKUP_DIR"
    rsync -avz -e ssh $SOURCE $DESTINATION$FULL_BACKUP_DIR

    # Delete the previous full backup (if exists)
    PREVIOUS_FULL_BACKUP=$(ssh rsync_adm@backup-srv "ls -dt ~/backup_storage/full-* 2>/dev/null | head -n 1")
    if [ -n "$PREVIOUS_FULL_BACKUP" ]; then
        echo "Deleting the previous full backup: $PREVIOUS_FULL_BACKUP"
        ssh rsync_adm@backup-srv "rm -rf $PREVIOUS_FULL_BACKUP"
    fi

# Perform differential backups from Monday to Saturday
elif [ "$DAY_OF_WEEK" -ne 7 ]; then
    # Find the last Saturday's full backup directory
    LAST_SATURDAY=$(date -d "last Saturday" +%Y-%m-%d)
    FULL_BACKUP_DIR="full-${LAST_SATURDAY}"

    # Check if the full backup exists on the server
    if ssh rsync_adm@backup-srv [ ! -d "~/backup_storage/$FULL_BACKUP_DIR" ]; then
        echo "Error: Last Saturday's full backup not found. Cannot perform differential backup."
        exit 1
    fi

    echo "Creating a differential backup based on last Saturday's full backup in $DIFFERENTIAL_BACKUP_DIR"
    rsync -avz --delete -e ssh --link-dest=$DESTINATION$FULL_BACKUP_DIR $SOURCE $DESTINATION$DIFFERENTIAL_BACKUP_DIR
else
    echo "No backup scheduled for Sunday."
fi

# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
