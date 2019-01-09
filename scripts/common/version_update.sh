#!/bin/bash
#SCRIPT_VERSION=0.1

LINUX_USERNAME=azureAdmin
BASE_URI=https://raw.githubusercontent.com/marcvaneijk/azurestack-monitor/master

# Download files.json (contains a reference to all other files)
sudo curl -s ${BASE_URI}/common/files.json --output /azmon/common/files.json

# Download the all the files from files.json
FILES_ARRAY=$(sudo cat /azmon/common/files.json | jq -r ".[] | .[] | .path")

for i in $FILES_ARRAY
do
    sudo curl ${BASE_URI}/scripts${i} --output /azmon${i}
done

# change the permissions for all files in /azmon for jobs and common
sudo chmod -R 755 /azmon/jobs
sudo chmod -R 755 /azmon/common

# Delete existing crontab and create a new one
sudo crontab -u $LINUX_USERNAME -r
sudo crontab -u $LINUX_USERNAME /azmon/common/cron_tab.conf