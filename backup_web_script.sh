DIR_Destination="/Your/External/DiskDrive/BackupLocation" # Once in the folder in Linux press Ctrl+L and you should be able to see the folder path in your Linux File Manager. 
 
params=(
    -avh 
    --stats
    --exclude='#recycle'
    --exclude='@eaDir'
    --no-perms --no-owner --no-group
    --exclude='Resources/Images'
    --exclude='*.gz.*'
    --exclude='*.mrimg'
    --exclude='*.ova'
    --exclude='$RECYCLE.BIN'
    --exclude='*.Spotlight-*'
    --exclude='*.wim'
    --exclude='*.dmg'
    --exclude='*.app'
    --delete-before
    --chmod=ugo=rwX #You only need this if you specifically want to copy files without their source's permissions. 
 
 
DIR_Source=root@172.16.1.251:/volume1/FolderName #The host using IP or Hostname and then the folder that has your folders in it you need backed up. 
DIR_Destination=/media/mnt/device/sda1/Folder/ #The folder that your saving the source into. 
DATESTAMP=$(date +%Y%m%d%H%M%S) #The Timestamp you would like for hte Log File. 
LOGFileLoc=/media/mnt/device/sda1/Logs/FOlderName/${DATESTAMP}.DescriptiveName-backup-log.txt 
 
rsync --log-file=$LOGFileLoc $DIR_Source $DIR_Destination "${params[@]}"
 
#If you have more data to backup - Simply copy lines 22 - 27 and paste below for as many top-level folders as needed.
# 
# Refer to this video for a demo: https://youtu.be/wQF9hLjx5K4