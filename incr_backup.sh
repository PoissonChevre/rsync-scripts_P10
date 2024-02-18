#!/bin/bash

# -----------------------------------------------------------------------------
# Incremental Backup Script
# -----------------------------------------------------------------------------
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs an incremental backup using rsync, keeping backups
# from the specified number of days and ensuring at least the two most recent
# backups are always retained.
# Usage: ./backup_script.sh <SRC_DIR> <RETENTION>
# Example: ./backup_script.sh /path/to/SRC_DIR/ 7
# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
#       https://explainshell.com/explain/1/rsync
# -----------------------------------------------------------------------------

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <SRC_DIR> <RETENTION>"
    exit 1
fi

# Assign arguments to variables
SRC_DIR="$1"
RETENTION="$2"
DST_DIR="rsync_adm@backup-srv:~/backup_storage/"
TIMESTAMP=$(date +%Y%m%d-%a)
PARAMTERS=(
    -a                      # --archive, equivalent to -rlptgoD (--recusrsive;--links;--perms;--times;--group;--owner;equivalent to --devices & --specials)
    -v                      # --verbose
    -P                      # equivalent to --partial --progress
    -e ssh                  # ssh remote
)

# Perform an incremental backup
perform_incr_backup() {
    local LAST_BACKUP=$(find_last_backup)
    if [ -z "$LAST_BACKUP" ]; then
        echo "No previous backup found. Proceeding without --link-dest."
        rsync "${PARAMETERS[*]}" "${SRC_DIR}" "${DST_DIR}backup-${TIMESTAMP}/"
    else
        echo "Performing incremental backup using the most recent backup as reference."
        rsync "${PARAMETERS[*]}" --link-dest="${LAST_BACKUP}" "${SRC_DIR}" "${DST_DIR}backup_incr-${TIMESTAMP}/"
    fi
}

# Find the most recent backup directory
find_last_backup() {
    ssh rsync_adm@backup-srv "ls -d ${DST_DIR}backup-* 2>/dev/null | sort | tail -n 1"
}

# Clean up old backups, keeping only backups from the last N days and
# ensuring the two most recent backups are retained regardless of age.
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    ssh rsync_adm@backup-srv "find ${DST_DIR} -maxdepth 1 -name 'backup_incr_*' -mtime +${RETENTION} 2>/dev/null | sort | head -n -2 | xargs -r rm -rf"
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


