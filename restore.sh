#!/bin/bash

# Restoration Script
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs restoration of backups using rsync.
# Usage: ./restore_script.sh

SRC_DIR="/home/rsync_adm/"
DST_DIR="/home/rsync_adm/backup_storage/"
REMOTE="rsync_adm@backup-srv"
TIMESTAMP=$(date +%Y%m%d_%H%M)
PARAMETERS=(
    -a              # archive mode; equals -rlptgoD (no -H,-A,-X)
    -v              # increase verbosity
    -P              # show progress during transfer
    -e "ssh"        # use SSH for remote connection
)
LOG_FILE_INCR="--log-file=/var/log/rsync/incr_restore.log"
LOG_FILE_DIFF="--log-file=/var/log/rsync/diff_restore.log"
TARGET_DIR_ARR=(
    "FICHIERS"
    "MACHINES"
    "MAILS"
    "RH"
    "SITE"
    "TICKETS"
)

restore_file_subdir() {
    local SEL_DIRECTORY="$1"

    while true; do
        echo "Listing files and subdirectories available for restore in $SEL_DIRECTORY directory: "
        ssh "$REMOTE" "cd $DST_DIR/$SEL_DIRECTORY/ && ls -Rlh"

        read -p "Enter the path of the file or subdirectory to restore (e.g., 'file.txt', 'subdirectory/file2.txt', or all 'subdirectory/'): " RESTORE_PATH

        local DESTINATION_DIR="$HOME/$USER/RESTORE/${SEL_DIRECTORY}_$TIMESTAMP"
        mkdir -p "$DESTINATION_DIR"

        rsync -r  "${PARAMETERS[@]}" "$LOG_FILE_INCR" "$REMOTE:$DST_DIR/$SEL_DIRECTORY/$RESTORE_PATH" "$DESTINATION_DIR/"

        echo "Restoration of '$RESTORE_PATH' from $SEL_DIRECTORY to $DESTINATION_DIR successful."

        read -p "Do you want to restore another file or subdirectory? [Y]/[N]: " RESTORE_ANOTHER

        if [[ "$RESTORE_ANOTHER" =~ ^[Yy]$ ]]; then
            continue
        else
            return
        fi
    done
}

restore_directory() {
    local SELECTED_DIRECTORY="$1"

    while true; do
        echo "Listing snapshots available for restore in $SELECTED_DIRECTORY directory: "
        BACKUP_DIRS=$(ssh "$REMOTE" "cd $DST_DIR/$SELECTED_DIRECTORY/ && ls -d */" 2>/dev/null)

        read -p "Enter the date of the backup to restore (format: yyyymmdd_HHMM), or enter '0' to return: " BACKUP_DATE
        if [[ "$BACKUP_DATE" == "0" ]]; then
            echo "Returning to the main directory selection prompt."
            return
        fi

        MATCHING_DIRS=$(echo "$BACKUP_DIRS" | grep -o "_${BACKUP_DATE}/")
        if [ -n "$MATCHING_DIRS" ]; then
            echo "Matching backups for the entered date:"
            echo "$MATCHING_DIRS"
            RESTORE_TARGET=$(echo "$MATCHING_DIRS" | head -n 1)

            local DESTINATION_DIR="$HOME/$USER/RESTORE_${RESTORE_TARGET}"
            mkdir -p "$DESTINATION_DIR"

            local LOG_FILE="${LOG_FILE_INCR}"
            if [ "$SELECTED_DIRECTORY" == "MACHINES" ]; then
                LOG_FILE="${LOG_FILE_DIFF}"
            else
                LOG_FILE="${LOG_FILE_INCR}"
            fi

            if rsync -r "${PARAMETERS[@]}" "$LOG_FILE" "$REMOTE:$DST_DIR/$SELECTED_DIRECTORY/$RESTORE_TARGET" "$DESTINATION_DIR/"; then
                echo "Restoration of backup '$RESTORE_TARGET' from $SELECTED_DIRECTORY to $DESTINATION_DIR successful."
            else
                echo "Error: Restoration of backup '$RESTORE_TARGET' from $SELECTED_DIRECTORY failed."
            fi

            return
        else
            echo "Error: No matching backup found for the entered date '$BACKUP_DATE' in $SELECTED_DIRECTORY directory."
            echo "Restoration canceled."
            return
        fi
    done
}

restore_option_prompt() {
    while true; do
        read -p "Do you want to restore a file (F), the entire directory (G), or exit (0)? " RESTORE_OPTION
        case $RESTORE_OPTION in
            "F" | "f")
                restore_file_subdir
                ;;
            "G" | "g")
                restore_directory
                ;;
            "0")
                echo "Exiting."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter 'F' for file, 'G' for the entire directory, or '0' to exit."
                ;;
        esac
    done
}

prompt_user_directory_type() {
    local VALID_CHOICE=false
    while [ "$VALID_CHOICE" == false ]; do
        echo "Choose the directory to restore (number 0-6), 0 to EXIT: "
        echo "[0] EXIT"
        for ((i=0; i<${#TARGET_DIR_ARR[@]}; i++)); do
            echo "[$i] ${TARGET_DIR_ARR[i]}"
        done

        read -p "Enter your choice (0-6): " USER_CHOICE

        if [[ "$USER_CHOICE" =~ ^[0-6]$ ]]; then
            if [ "$USER_CHOICE" -eq 0 ]; then
                echo "Exiting."
                exit 0
            fi
            local SEL_DIRECTORY="${TARGET_DIR_ARR[USER_CHOICE]}"
            if [ "$SEL_DIRECTORY" == "MACHINES" ]; then
                restore_directory "$SEL_DIRECTORY"
            else
                restore_option_prompt
            fi
            VALID_CHOICE=true
        else
            echo "Invalid choice. Please enter a number between 0 and 6."
        fi
    done
}

main() {
    echo "Starting restoration process..."
    while true; do
        prompt_user_directory_type
    done
}

# Execute the main function
main

