#!/bin/bash

echo "============== Set Argument Object ..."
ARGUMENTS_JSON=$1
ARGUMENTS_BLOB_ENDPOINT=$2

###################################################
#######   Requires Internet Connectivity   ########
###################################################

echo "============== Installing Prerequisistes ..."

#update your existing list of packages
sudo apt-get update

# prerequisite packages
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq apache2-utils

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
sudo docker pull nginx

####################################################
######   No Internet Connectivity Required   #######
####################################################

# FQDN Remove storageaccountname. from blob endpoint
FQDN=${ARGUMENTS_BLOB_ENDPOINT#*.}
# FQDN Remove blob. from blob endpoint
FQDN=${FQDN#*.}
# FQDN Remove trailing backslash from blob endpoint
FQDN=${FQDN%/*}

BASE_URI=$(echo $ARGUMENTS_JSON | jq -r ".baseUrl")
SUBSCRIPTION_ID=$(echo $ARGUMENTS_JSON | jq -r ".subscriptionId")
APP_ID=$(echo $ARGUMENTS_JSON | jq -r ".appId")
APP_KEY=$(echo $ARGUMENTS_JSON | jq -r ".appKey")
TENANT_ID=$(echo $ARGUMENTS_JSON | jq -r ".tenantId")
GRAFANA_ADMIN=$(echo $ARGUMENTS_JSON | jq -r ".grafanaPassword")
LINUX_USERNAME=$(echo $ARGUMENTS_JSON | jq -r ".linuxUsername")

# Create a directory structure for the project
sudo mkdir /azmon
sudo mkdir /azmon/jobs
sudo mkdir /azmon/common
sudo mkdir /azmon/influxdb
sudo mkdir /azmon/grafana
sudo mkdir /azmon/grafana/datasources
sudo mkdir /azmon/grafana/dashboards
sudo mkdir /azmon/export
sudo mkdir /azmon/nginx

# Copy the waagent cert to the project folder
sudo cp /var/lib/waagent/Certificates.pem /azmon/common/Certificates.pem

# Download files.json (contains a reference to all other files)
sudo curl -s ${BASE_URI}/scripts/common/files.json --output /azmon/common/files.json

# Download the all the files from files.json
FILES_ARRAY=$(sudo cat /azmon/common/files.json | jq -r ".[] | .[]")

for i in $FILES_ARRAY
do
    sudo curl ${BASE_URI}/scripts${i} --output /azmon${i}
done

# change the permissions for all files in /azmon/azurecli 
sudo chmod -R 755 /azmon/jobs
sudo chmod -R 755 /azmon/common
sudo chmod -R 755 /azmon/export

echo "=========== Initialize Docker Swarm ..."

# Install Docker Swarm
sudo docker swarm init

echo "=========== Create Docker Secrets ..."

# Create docker secrets
printf $FQDN | sudo docker secret create fqdn -
printf $SUBSCRIPTION_ID | sudo docker secret create subscription_Id -
printf $APP_ID | sudo docker secret create app_Id -
printf $APP_KEY | sudo docker secret create app_Key -
printf $TENANT_ID | sudo docker secret create tenant_Id -
printf $GRAFANA_ADMIN | sudo docker secret create grafana_Admin -

# Create nginx secret
sudo htpasswd -bc /azmon/nginx/.htpasswd admin $GRAFANA_ADMIN

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

echo "=========== Start NGINX container"
sudo docker service create \
     --name nginx \
     --detach \
     --restart-condition any \
     --network="azmon" \
     --mount type=bind,src=/azmon/export,dst=/azmon/export \
     --mount type=bind,src=/azmon/nginx/nginx.conf,dst=/etc/nginx/nginx.conf \
     --mount type=bind,src=/azmon/nginx/.htpasswd,dst=/etc/nginx/.htpasswd \
     --publish published=8080,target=80 \
     nginx


echo "=========== Configure cron"
sudo crontab -u $LINUX_USERNAME /azmon/common/cron_tab.conf

echo "=========== Retention Policy"
curl -sX POST "http://localhost:8086/query?db=azmon" --data-urlencode "q=CREATE RETENTION POLICY "azmon_90_days" ON "azmon" DURATION 90d REPLICATION 1 SHARD DURATION 7d DEFAULT"