#!/bin/bash
#SCRIPT_VERSION=0.1

sudo cat /azmon/common/files.json | jq -r ".jobs[] | .name"

LINUX_USERNAME=azureAdmin
BASE_URI=https://raw.githubusercontent.com/marcvaneijk/azurestack-monitor/master


for i in "${SCRIPT_ARRAY[@]}"
do
    sudo curl -s ${BASE_URI}/scripts${i} --output /azmon${i}
done

# change the permissions for all files in /azmon for jobs and common
sudo chmod -R 755 /azmon/jobs
sudo chmod -R 755 /azmon/common

# Delete existing crontab and create a new one
sudo crontab -u $LINUX_USERNAME -r
sudo crontab -u $LINUX_USERNAME /azmon/common/cron_tab.conf