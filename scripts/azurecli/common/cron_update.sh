#!/bin/bash
#SCRIPT_VERSION=0.1

LINUX_USERNAME=azureAdmin
BASE_URI=https://raw.githubusercontent.com/marcvaneijk/azurestack-monitor/master

SCRIPT_ARRAY=(
    /azurecli/common/functions.sh
    /azurecli/common/cron_job.sh
    /azurecli/common/cron_tab.conf
    /azurecli/jobs/admin_arm.sh
    /azurecli/jobs/admin_portal.sh
    /azurecli/jobs/admin_pnu.sh
    /azurecli/jobs/tenant_arm.sh
    /azurecli/jobs/tenant_portal.sh
    /azurecli/jobs/tenant_storage.sh
)

for i in "${SCRIPT_ARRAY[@]}"
do
    sudo curl ${BASE_URI}/scripts${i} --output /azmon${i}
done

# Delete existing crontab and create a new one
sudo crontab -u $LINUX_USERNAME -r
sudo crontab -u $LINUX_USERNAME /azmon/azurecli/common/cron_tab.conf