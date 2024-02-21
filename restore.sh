#!/bin/bash

# Restoration Script
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs restoration of backups using rsync.
# Usage: ./restore_script.sh

DST_DIR="/home/rsync_adm/backup_storage"
REMOTE="rsync_adm@backup-srv"
PARAMETERS=(
    -a              # archive mode; equals -rlptgoD (no -H,-A,-X)
    -q              # --quiet
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

    echo "Listing files and subdirectories available for restore in $MATCHING_DIR : "
    ssh "$REMOTE" "cd $DST_DIR/$SEL_DIR/$MATCHING_DIR/ && ls -R"
    read -p "Enter the path of the file/subdirectory to restore (e.g., 'file.ext', 'subdirectory/file2.ext', or all 'subdirectory/'): " RESTORE_PATH
    if rsync -r "${PARAMETERS[@]}" "$LOG_FILE" "$REMOTE:$DST_DIR/$SEL_DIR/$MATCHING_DIR/$RESTORE_PATH" "$RESTORE_DIR"; then
        echo "Restoration of backup '$RESTORE_PATH' from $MATCHING_DIR to $RESTORE_DIR successful."
    else
        echo "Error: Restoration of backup '$RESTORE_PATH' from $SEL_DIR failed."
    fi
    read -p "Do you want to restore another file or subdirectory? [Y]/[N]: " RESTORE_ANOTHER
    if [[ "$RESTORE_ANOTHER" =~ ^[Yy]$ ]]; then
        continue
    else
        prompt_user_directory_type
    fi
}

restore_directory() {

    if rsync -r "${PARAMETERS[@]}" "$LOG_FILE" "$REMOTE:$DST_DIR/$SEL_DIR/$MATCHING_DIR/" "$RESTORE_DIR"; then
        echo "Restoration of backup '$MATCHING_DIR' from $SEL_DIR to $RESTORE_DIR successful."
    else
        echo "Error: Restoration of backup '$MATCHING_DIR' from $SEL_DIR failed."
    fi
    prompt_user_directory_type
}

restore_option_prompt() {

    while true; do
        read -p "Do you want to restore a file/subdirectory (F), the entire directory (G), or go back (0)? " RESTORE_OPTION
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
                echo "Invalid choice. Please enter 'F' for file, 'G' for the entire directory, or '0' to go back."
                ;;
        esac
    done
}

list_backups() {

    echo "Listing snapshots available in $SEL_DIR : "
    ssh "$REMOTE" "cd $DST_DIR/$SEL_DIR/ && ls "
    read -p "Enter the date of the backup to restore (format: YYYYmmdd_HHMM), or enter '0' to go back: " BACKUP_DATE
    if [[ "$BACKUP_DATE" == "0" ]]; then
        return
    fi
    MATCHING_DIR=$(ssh "$REMOTE" "ls "$DST_DIR/$SEL_DIR/" | grep "$BACKUP_DATE"")
    if [ -n "$MATCHING_DIR" ]; then
        echo "Matching backup for the entered date: $MATCHING_DIR"
        RESTORE_DIR="$HOME/RESTORE/$SEL_DIR_$MATCHING_DIR"
        mkdir -p "$HOME/RESTORE/"
    else
        echo "Error: No matching backup found for the entered date '$BACKUP_DATE' in $SEL_DIR directory."
        echo "Restoration canceled."
    continue
    fi
}

prompt_user_directory_type() {
    local valid_choice=false
    while [ "$valid_choice" == false ]; do
        echo "Choose a directory to restore: "
        echo "[0] EXIT"
        for ((i=0; i<${#TARGET_DIR_ARR[@]}; i++)); do
            echo "[$((i+1))] ${TARGET_DIR_ARR[i]}"
        done

        read -p "Enter your choice (0-6), 0 to EXIT: " CHOICE

        case ${CHOICE} in    
            0)    
                    echo "bye"
                    exit 0
                ;;
            [1-6])
                SEL_DIR="${TARGET_DIR_ARR[$((CHOICE-1))]}"
                if [ "$SEL_DIR" == "MACHINES" ]; then
                    LOG_FILE="${LOG_FILE_DIFF}"
                else 
                    LOG_FILE="${LOG_FILE_INCR}"
                fi
                list_backups
                restore_option_prompt 
                valid_choice=true
                ;;
            *)
                echo "Invalid choice. Please enter a number between 0 and 6."
                ;;
        esac
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

