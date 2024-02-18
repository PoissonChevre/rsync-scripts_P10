#!/bin/bash

# -----------------------------------------------------------------------------
# Differential Backup Script
# -----------------------------------------------------------------------------
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs a differential backup using rsync, keeping backups
# from the specified number of days and ensuring at least the two most recent
# backups are always retained.
# Usage: ./backup_script.sh <SRC_DIR> <RETENTION>
# Example: ./backup_script.sh /path/to/SRC_DIR/ 7
# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
#       https://explainshell.com/explain/1/rsync
#       dd if=/dev/zero of=/chemin/vers/repertoire/MACHINE/vm-1Go bs=4096 count=262144 (créé un fichier de 1Go de zéros binaires, 262144 x 4Ko)
#       dd i f=/dev/zero of=/chemin/vers/repertoire/MACHINE/vm-2Go bs=4096 count=524288 (créé un fichier de 2Go de zéros binaires, 524288 x 4Ko)
#       cat vm-1Go vm-2Go >> vm-3Go (créé un fichier de 3Go de zéros binaires)
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
PARAMETERS=(
    -a                      # --archive, equivalent to -rlptgoD (--recusrsive;--links;--perms;--times;--group;--owner;equivalent to --devices & --specials)
    -v                      # --verbose
    -P                      # equivalent to --partial --progress
    -e ssh                  # ssh remote
)

# Perform a differential backup
perform_diff_backup() {
    local LAST_FULL_BACKUP=$(find_last_full_backup)
    local CURRENT_TIME=$(date +%s)
    
    if [ -z "$LAST_FULL_BACKUP" ] || [ $((CURRENT_TIME - $(stat -c %Y "$LAST_FULL_BACKUP"))) -ge $((RETENTION * 86400)) ]; then
        # No existing full backup or the last full backup is older than RETENTION days
        echo "No previous full backup found or the last full backup is older than ${RETENTION} days. Creating a new full backup."
        rsync "${PARAMETERS[*]}" "${SRC_DIR}" "${DST_DIR}backup_diff-FULL-${TIMESTAMP}/"

        # Remove the previous full backup
        echo "Removing the previous full backup: $LAST_FULL_BACKUP"
        ssh rsync_adm@backup-srv "rm -rf $LAST_FULL_BACKUP"
    else
        # Differential backup using the most recent full backup as reference
        echo "Performing differential backup using the most recent full backup as reference."
        rsync "${PARAMETERS[*]}" --link-dest="${LAST_FULL_BACKUP}" "${SRC_DIR}" "${DST_DIR}backup_diff-${TIMESTAMP}/"
    fi
}

# Find the most recent full backup directory
find_last_full_backup() {
    ssh rsync_adm@backup-srv "ls -d ${DST_DIR}backup_diff_full-* 2>/dev/null | sort | tail -n 1"
}

# Clean up old backups, keeping only backups from the last N days and
# ensuring the two most recent backups are retained regardless of age.
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    
    # Remove old backups (full and incremental) based on RETENTION days
    ssh rsync_adm@backup-srv "find ${DST_DIR} -maxdepth 1 \( -name 'backup_diff_full_*' -o -name 'backup_diff_incr_*' \) -mtime +${RETENTION} 2>/dev/null | sort | xargs -r rm -rf"
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
