#!/bin/bash

echo "============== Set Argument Object ..."
ARGUMENTS_JSON=$1

###################################################
#######   Requires Internet Connectivity   ########
###################################################

echo "============== Installing Prerequisistes ..."

#update your existing list of packages
sudo apt-get update

# prerequisite packages which let apt use packages over HTTPS
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq

# add the GPG key for the official Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repository to APT sources:
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update package database with Docker packages from new repo
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce
	
echo "=========== Donwload docker images ..."

sudo docker pull influxdb
sudo docker pull grafana/grafana
sudo docker pull microsoft/azure-cli


####################################################
######   No Internet Connectivity Required   #######
####################################################

BASE_URI=$(echo $ARGUMENTS_JSON | jq -r ".baseUrl")
FQDN=$(echo $ARGUMENTS_JSON | jq -r ".fqdn")
SUBSCRIPTION_ID=$(echo $ARGUMENTS_JSON | jq -r ".subscriptionId")
APP_ID=$(echo $ARGUMENTS_JSON | jq -r ".appId")
APP_KEY=$(echo $ARGUMENTS_JSON | jq -r ".appKey")
TENANT_NAME=$(echo $ARGUMENTS_JSON | jq -r ".tenantName")
GRAFANA_ADMIN=$(echo $ARGUMENTS_JSON | jq -r ".grafanaPassword")
LINUX_USERNAME=$(echo $ARGUMENTS_JSON | jq -r ".linuxUsername")

# Create a directory structure for the project
sudo mkdir /azmon
sudo mkdir /azmon/azurecli
sudo mkdir /azmon/azurecli/jobs
sudo mkdir /azmon/azurecli/common
sudo mkdir /azmon/influxdb
sudo mkdir /azmon/grafana
sudo mkdir /azmon/grafana/datasources
sudo mkdir /azmon/grafana/dashboards

# Download the files
sudo curl -s "$BASE_URI"/scripts/azurecli/common/auth.sh --output /azmon/azurecli/common/auth.sh
sudo curl -s "$BASE_URI"/scripts/azurecli/common/cron_job.sh --output /azmon/azurecli/common/cron_job.sh
sudo curl -s "$BASE_URI"/scripts/azurecli/common/cron_tab.txt --output /azmon/azurecli/common/cron_tab.txt
sudo curl -s "$BASE_URI"/scripts/azurecli/jobs/pnu.sh --output /azmon/azurecli/jobs/pnu.sh
sudo curl -s "$BASE_URI"/scripts/grafana/dashboards/azmon.json --output /azmon/grafana/dashboards/azmon.json
sudo curl -s "$BASE_URI"/scripts/grafana/datasources/influxdb.yml --output /azmon/grafana/datasources/influxdb.yml

# Copy the waagent cert to the project folder
sudo cp /var/lib/waagent/Certificates.pem /azmon/azurecli/common/Certificates.pem

# change the permissions for all files in /azmon/azurecli 
sudo chmod -R 755 /azmon/azurecli

echo "=========== Initialize Docker Swarm ..."

# Install Docker Swarm
sudo docker swarm init

echo "=========== Create Docker Secrets ..."

# Create the secrets
printf $FQDN | sudo docker secret create fqdn -
printf $SUBSCRIPTION_ID | sudo docker secret create subscription_Id -
printf $APP_ID | sudo docker secret create app_Id -
printf $APP_KEY | sudo docker secret create app_Key -
printf $GRAFANA_ADMIN | sudo docker secret create grafana_Admin -

echo "=========== Create network"
#sudo docker network ls
sudo docker network create --driver overlay "azmon"

echo "=========== Start InfluxDB container"
sudo docker service create \
     --name influxdb \
     --detach \
     --restart-condition any \
     --network="azmon" \
     --mount type=bind,src=/azmon/influxdb,dst=/var/lib/influxdb \
     --publish published=8086,target=8086 \
     --env INFLUXDB_DB=azmon \
     influxdb

echo "=========== Start Grafana container"
sudo docker service create \
     --name grafana \
     --detach \
     --restart-condition any \
     --network="azmon" \
     --mount type=bind,src=/azmon/grafana,dst=/etc/grafana/provisioning \
     --publish published=3000,target=3000 \
     --secret grafana_Admin \
     --env GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_Admin \
     grafana/grafana

echo "=========== Configure cron"
sudo crontab -u $LINUX_USERNAME /azmon/azurecli/common/cron_tab.txt