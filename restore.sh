#!/bin/bash

# -----------------------------------------------------------------------------
# Backup Restoration Script
# -----------------------------------------------------------------------------
# Author: Renaud CHARLIER
# Date: 18-02-2024
# Description: Performs restoration of backups using rsync. Interactive script 
# with prompts asking the user the location of the files/directory and the type
# of restore to perform, entire-directory or file-specific.
# Usage: ./restore_script.sh
# Note: Ensure SSH password-less authentication is set up for rsync_adm@backup-srv.
## GITHUB: https://github.com/PoissonChevre/rsync-scripts_P10
# -----------------------------------------------------------------------------

DST_DIR="/home/rsync_adm/backup_storage"
REMOTE="rsync_adm@backup-srv"
PARAMETERS=(
    -a              # archive mode; equals -rlptgoD (no -H,-A,-X)
    -q              # --quiet
#    -v              # --verbose
    -e "ssh"        # use SSH for remote connection
)
# different log file for incremental and differential
LOG_FILE_INCR="--log-file=/var/log/rsync/incr_restore.log"
LOG_FILE_DIFF="--log-file=/var/log/rsync/diff_restore.log"
# 2D table containing backup directories
TARGET_DIR_ARR=("FICHIERS" "MACHINES" "MAILS" "RH" "SITE" "TICKETS")

# Function to restore a file or a subdirectory
restore_file_subdir() {
    echo "Listing files and subdirectories available for restore in $MATCHING_DIR : "
    ssh "$REMOTE" "cd $DST_DIR/$SEL_DIR/$MATCHING_DIR/ && ls -R"
    read -p "Enter the path of the file/subdirectory to restore (e.g., 'file.ext', 'subdirectory/file2.ext', or all the 'subdirectory'): " RESTORE_PATH

    # Perform rsync to restore the chosen file or subdirectory
    if rsync -r "${PARAMETERS[@]}" "$LOG_FILE" "$REMOTE:$DST_DIR/$SEL_DIR/$MATCHING_DIR/$RESTORE_PATH" "$RESTORE_DIR"; then
        echo "Restoration of backup '$RESTORE_PATH' from $MATCHING_DIR to $RESTORE_DIR successful."
    else
        echo "Error: Restoration of backup '$RESTORE_PATH' from $MATCHING_DIR failed."
    fi

    read -p "Do you want to restore another file or subdirectory? [Y]/[N]: " RESTORE_ANOTHER
    if [[ "$RESTORE_ANOTHER" =~ ^[Yy]$ ]]; then
        continue
    else
        prompt_user_directory_type
    fi
}

# Function to restore an entire directory
restore_directory() {
    # Perform rsync to restore the entire directory
    if rsync -r "${PARAMETERS[@]}" "$LOG_FILE" "$REMOTE:$DST_DIR/$SEL_DIR/$MATCHING_DIR/" "$RESTORE_DIR"; then
        echo "Restoration of backup '$MATCHING_DIR' from $SEL_DIR to $RESTORE_DIR successful."
    else
        echo "Error: Restoration of backup '$MATCHING_DIR' from $SEL_DIR failed."
    fi
    prompt_user_directory_type
}

# Function to prompt user for file or directory restoration option
restore_option_prompt() {
    while true; do
        read -p "Do you want to restore a file/subdirectory [F], the entire directory [G], or go back [0]? " RESTORE_OPTION
        case $RESTORE_OPTION in
            "F" | "f")
                restore_file_subdir
                ;;
            "G" | "g")
                restore_directory
                ;;
            "0")
                return
                ;;
            *)
                echo "Invalid choice. Please enter 'F' for file, 'G' for the entire directory, or '0' to go back."
                ;;
        esac
    done
}

# Function to list available backups 
list_backups() {
    echo "Listing snapshots available in $SEL_DIR : "
    ssh "$REMOTE" "cd $DST_DIR/$SEL_DIR/ && ls "
    read -p "Enter the date & hour of the backup to restore [YYYYmmdd_HHMM], or enter [0] to go back: " BACKUP_DATE

    # Check if the user wants to go back to the main directory selection
    if [[ "$BACKUP_DATE" == "0" ]]; then
        prompt_user_directory_type
    fi

    # Find matching backup directory
    MATCHING_DIR=$(ssh "$REMOTE" "ls "$DST_DIR/$SEL_DIR/" | grep "$BACKUP_DATE"")
    if [ -n "$MATCHING_DIR" ]; then
        echo "Matching backup for the entered date: $MATCHING_DIR"
        RESTORE_DIR="$HOME/RESTORE/${SEL_DIR}_$MATCHING_DIR"
        mkdir -p "$HOME/RESTORE/" 
    else
        echo "Error: No matching backup found for the entered date '$BACKUP_DATE' in $SEL_DIR directory."
        echo "Restoration canceled."
        return
    fi
}

# Function to prompt user for directory selection
prompt_user_directory_type() {
    local valid_choice=false
    while [ "$valid_choice" == false ]; do
        echo "Choose a directory to restore: "
        for ((i=0; i<${#TARGET_DIR_ARR[@]}; i++)); do
            echo "[$((i+1))] ${TARGET_DIR_ARR[i]}"
        done

        read -p "Enter your choice [0-6], [0] to EXIT: " CHOICE

        case ${CHOICE} in    
            0)    
                    echo "bye bye Elohim"
                    exit 0
                ;;
            [1-6])
                SEL_DIR="${TARGET_DIR_ARR[$((CHOICE-1))]}"
                # Set the appropriate log file 
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

# Main function to start the restoration process
main() {
    echo "Starting restoration process..."
    while true; do
        prompt_user_directory_type
    done
}

# Execute the main function
main
