# morgan
# https://explainshell.com/explain/1/rsync
rsync -aRbcxi --checksum --delete --ignore-missing-args -e 'ssh -p 2222' /home/morgan/./fichiers --link-dest=/home/morgan/fichiers/backup_14022024 morgan@192.168.1.253:/home/morgan/fichiers/backup_16022024
