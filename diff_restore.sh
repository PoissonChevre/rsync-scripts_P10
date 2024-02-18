#!/bin/bash

# -----------------------------------------------------------------------------
# Restoration Script
# -----------------------------------------------------------------------------
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs restoration of backups using rsync.
# Usage: ./diff_restore.sh <RESTORE_DATE> <RESTORE_DIR>
# Example: ./diff_restore.sh 20240218 /path/to/restore_directory
# -----------------------------------------------------------------------------

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <RESTORE_DATE> <RESTORE_DIR>"
    exit 1
fi

# Assign arguments to variables
RESTORE_DATE="$1"
RESTORE_DIR="$2"
SRC_DIR="rsync_adm@backup-srv:~/backup_storage/"

# Perform restoration
perform_restore() {
    echo "Performing restoration..."
    rsync -a "${SRC_DIR}backup_diff_full_${RESTORE_DATE}/" "${RESTORE_DIR}/"
    
    # Restore incremental backups if available
    if [ -d "${SRC_DIR}backup_diff_incr_${RESTORE_DATE}" ]; then
        rsync -a --link-dest="${SRC_DIR}backup_diff_full_${RESTORE_DATE}/" "${SRC_DIR}backup_diff_incr_${RESTORE_DATE}/" "${RESTORE_DIR}/"
    fi
}

# Main execution flow
main() {
    echo "Starting restoration process..."
    perform_restore
    echo "Restoration completed."
}

# Execute the main function
main
