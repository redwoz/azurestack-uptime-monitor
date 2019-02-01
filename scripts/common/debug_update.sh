#!/bin/bash
#SCRIPT_VERSION=0.3

LINUX_USERNAME=azureAdmin
BASE_URI=https://raw.githubusercontent.com/Azure/azurestack-uptime-monitor/master

# Download files.json (contains a reference to all other files)
sudo curl ${BASE_URI}/scripts/common/files.json --output /azs/common/files.json

# Download the all the files from files.json
FILES_ARRAY=$(sudo cat /azs/common/files.json | jq -r ".[] | .[]")

for i in $FILES_ARRAY
do
    sudo curl ${BASE_URI}/scripts${i} --output /azs${i}
done

# change the permissions for all files in /azs for jobs and common
sudo chmod -R 755 /azs/jobs
sudo chmod -R 755 /azs/common

# Delete existing crontab and create a new one
sudo crontab -u $LINUX_USERNAME -r
sudo crontab -u $LINUX_USERNAME /azs/common/cron_tab.conf