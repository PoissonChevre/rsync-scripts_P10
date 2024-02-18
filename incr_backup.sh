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

# Find the last backup
find_last_backup() {
    LAST_BACKUP=$(ssh rsync_adm@backup-srv "ls -d ${DST_DIR}backup_incr_* 2>/dev/null | tail -n 1")
    echo "Last backup: $LAST_BACKUP"
}

# Perform an incremental backup
perform_incr_backup() {
    find_last_backup
    # Si une sauvegarde incrémentale précédente est trouvée, effectuer une sauvegarde incrémentale
    if [ -n "$LAST_BACKUP" ]; then
        echo "Performing incremental backup..."
        rsync "${PARAMETERS[*]}" --link-dest="${LAST_BACKUP}" "${SRC_DIR}" "${DST_DIR}backup_incr-${TIMESTAMP}/"
    else
        # Si aucune sauvegarde incrémentale n'est trouvée, effectuer une sauvegarde complète
        echo "No previous incremental backup found. Performing a full backup..."
        rsync "${PARAMETERS[*]}" "${SRC_DIR}" "${DST_DIR}backup_incr-${TIMESTAMP}/"
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
