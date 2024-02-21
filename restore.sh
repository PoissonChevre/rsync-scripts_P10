#!/bin/bash

# Restoration Script
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs restoration of backups using rsync.
# Usage: ./restore_script.sh

SRC_DIR="/home/rsync_adm/"
DST_DIR="/home/rsync_adm/backup_storage"
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

    while true; do
        echo "Listing files and subdirectories available for restore in $SEL_DIR directory: "
        ssh "$REMOTE" "cd $DST_DIR/$SEL_DIR/ && ls -Rlh"

        read -p "Enter the path of the file or subdirectory to restore (e.g., 'file.txt', 'subdirectory/file2.txt', or all 'subdirectory/'): " RESTORE_PATH

        local DESTINATION_DIR="$HOME/$USER/RESTORE/${SEL_DIR}_$TIMESTAMP"
        mkdir -p "$DESTINATION_DIR"

        rsync -r  "${PARAMETERS[@]}" "$LOG_FILE_INCR" "$REMOTE:$DST_DIR/$SEL_DIR/$RESTORE_PATH" "$DESTINATION_DIR/"

        echo "Restoration of '$RESTORE_PATH' from $SEL_DIR to $DESTINATION_DIR successful."

        read -p "Do you want to restore another file or subdirectory? [Y]/[N]: " RESTORE_ANOTHER

        if [[ "$RESTORE_ANOTHER" =~ ^[Yy]$ ]]; then
            continue
        else
            prompt_user_directory_type
        fi
    done
}

restore_directory() {

    while true; do
        echo "Listing snapshots available for restore in $SEL_DIR directory: "
        ssh "$REMOTE" "cd $DST_DIR/$SEL_DIR/ && ls -d"

        read -p "Enter the date of the backup to restore (format: yyyymmdd_HHMM), or enter '0' to go back: " BACKUP_DATE
        if [[ "$BACKUP_DATE" == "0" ]]; then
            prompt_user_directory_type
        fi

        MATCHING_DIRS=$(echo "$BACKUP_DIRS" | grep -o "_${BACKUP_DATE}/")
        if [ -n "$MATCHING_DIRS" ]; then
            echo "Matching backups for the entered date:"
            echo "$MATCHING_DIRS"
            RESTORE_TARGET=$(echo "$MATCHING_DIRS" | head -n 1)

            local DESTINATION_DIR="$HOME/$USER/RESTORE_${RESTORE_TARGET}"
            mkdir -p "$DESTINATION_DIR"

            local LOG_FILE="${LOG_FILE_INCR}"
            if [ "$SEL_DIR" == "MACHINES" ]; then
                LOG_FILE="${LOG_FILE_DIFF}"
            else
                LOG_FILE="${LOG_FILE_INCR}"
            fi

            if rsync -r "${PARAMETERS[@]}" "$LOG_FILE" "$REMOTE:$DST_DIR/$SEL_DIR/$RESTORE_TARGET" "$DESTINATION_DIR/"; then
                echo "Restoration of backup '$RESTORE_TARGET' from $SEL_DIR to $DESTINATION_DIR successful."
            else
                echo "Error: Restoration of backup '$RESTORE_TARGET' from $SEL_DIR failed."
            fi

            return
        else
            echo "Error: No matching backup found for the entered date '$BACKUP_DATE' in $SEL_DIR directory."
            echo "Restoration canceled."
            prompt_user_directory_type
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
                prompt_user_directory_type
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
        echo "Choose the directory to restore: "
        echo "[0] EXIT"
        for ((i=0; i<${#TARGET_DIR_ARR[@]}; i++)); do
            echo "[$((i+1))] ${TARGET_DIR_ARR[i]}"
        done

        read -p "Enter your choice (0-6), 0 to EXIT: " USER_CHOICE

        if [[ "$USER_CHOICE" =~ ^[0-6]$ ]]; then
            if [ "$USER_CHOICE" -eq 0 ]; then
                echo "Exiting."
                exit 0
            fi
            SEL_DIR="${TARGET_DIR_ARR[USER_CHOICE]}"
            if [ "$SEL_DIR" == "MACHINES" ]; then
                restore_directory "$SEL_DIR"
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

