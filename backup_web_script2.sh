#!/bin/bash
# Path to folder for backups
dest=/opt/destination
# Source server IP address
ip=10.5.5.10
# Rsync user on source server
user=backup-user
# The resource we configured in the /etc/rsyncd.conf file on the source server
src=data
# Set the retention period for incremental backups in days
retention=30
# Start the backup process
rsync -a --delete --password-file=/etc/rsyncd.passwd ${user}@${ip}::${src} ${dest}/full/ --backup --backup-dir=${dest}/increment/`date +%Y-%m-%d`/
# Clean up incremental archives older than the specified retention period
find ${dest}/increment/ -mindepth 1 -maxdepth 2 -type d -mtime +${retention} -exec rm -rf {} \;