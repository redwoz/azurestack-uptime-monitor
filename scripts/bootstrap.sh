#!/bin/bash
SCRIPT_VERSION=0.1

echo "############ Date     : $(date)"
echo "############ Version  : $SCRIPT_VERSION"

echo "############ Set Argument Object"
ARGUMENTS_JSON=$1
ARGUMENTS_BLOB_ENDPOINT=$2
PREFIX=azsa

###################################################
#######   Requires Internet Connectivity   ########
###################################################

##################
echo "############ Installing Prerequisistes"

sudo apt-get update \
  && echo "## Pass: updated package database" \
  || echo "## Fail: failed to update package database"

sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq apache2-utils \
  && echo "## Pass: prereq packages installed" \
  || echo "## Fail: failed to install prereq packages"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
  && echo "## Pass: added GPG key for Docker repository" \
  || echo "## Fail: failed to add GPG key for Docker repository"

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  && echo "## Pass: added Docker repository to APT sources" \
  || echo "## Fail: failed to add Docker repository to APT sources"

sudo apt-get update \
  && echo "## Pass: updated package database with Docker packages" \
  || echo "## Fail: failed to update package database with Docker packages"

sudo apt-get install -y docker-ce \
  && echo "## Pass: installed docker-ce" \
  || echo "## Fail: failed to install docker-ce"

##################
echo "############ Donwload docker images"	

sudo docker pull influxdb \
  && echo "## Pass: pulled influxdb image from docker hub" \
  || echo "## Fail: failed to pull influxdb image from docker hub"

sudo docker pull grafana/grafana \
  && echo "## Pass: pulled grafana image from docker hub" \
  || echo "## Fail: failed to pull grafana image from docker hub"

sudo docker pull microsoft/azure-cli \
  && echo "## Pass: pulled microsoft/azure-cli image from docker hub" \
  || echo "## Fail: failed to pull microsoft/azure-cli image from docker hub"

sudo docker pull nginx \
  && echo "## Pass: pulled nginx image from docker hub" \
  || echo "## Fail: failed to pull nginx image from docker hub"

####################################################
######   No Internet Connectivity Required   #######
####################################################

##################
echo "############ Set variables"

FQDN=${ARGUMENTS_BLOB_ENDPOINT#*.} \
  && echo "## Pass: removed storageaccountname. from blob endpoint" \
  || echo "## Fail: failed to remove storageaccountname. from blob endpoint"

FQDN=${FQDN#*.} \
  && echo "## Pass: removed blob. from blob endpoint" \
  || echo "## Fail: failed to remove blob. from blob endpoint"

FQDN=${FQDN%/*} \
  && echo "## Pass: removed trailing backslash from blob endpoint" \
  || echo "## Fail: failed to remove trailing backslash from blob endpoint"

BASE_URI=$(echo $ARGUMENTS_JSON | jq -r ".baseUrl") \
  && echo "## Pass: set variable BASE_URI" \
  || echo "## Fail: failed to set variable BASE_URI"

SUBSCRIPTION_ID=$(echo $ARGUMENTS_JSON | jq -r ".subscriptionId") \
  && echo "## Pass: set variable SUBSCRIPTION_ID" \
  || echo "## Fail: failed to set variable SUBSCRIPTION_ID"

APP_ID=$(echo $ARGUMENTS_JSON | jq -r ".appId") \
  && echo "## Pass: set variable APP_ID" \
  || echo "## Fail: failed to set variable APP_ID"

APP_KEY=$(echo $ARGUMENTS_JSON | jq -r ".appKey") \
  && echo "## Pass: set variable APP_KEY" \
  || echo "## Fail: failed to set variable APP_KEY"

TENANT_ID=$(echo $ARGUMENTS_JSON | jq -r ".tenantId") \
  && echo "## Pass: set variable TENANT_ID" \
  || echo "## Fail: failed to set variable TENANT_ID"

GRAFANA_ADMIN=$(echo $ARGUMENTS_JSON | jq -r ".grafanaPassword") \
  && echo "## Pass: set variable GRAFANA_ADMIN" \
  || echo "## Fail: failed to set variable GRAFANA_ADMIN"

LINUX_USERNAME=$(echo $ARGUMENTS_JSON | jq -r ".linuxUsername") \
  && echo "## Pass: set variable LINUX_USERNAME" \
  || echo "## Fail: failed to set variable LINUX_USERNAME"

##################
echo "############ Files and directories"

sudo mkdir -p /$PREFIX/{jobs,common,influxdb,grafana/{datasources,dashboards},export,nginx} \
  && echo "## Pass: created directory structure" \
  || echo "## Fail: failed to create directory structure"

sudo cp /var/lib/waagent/Certificates.pem /$PREFIX/common/Certificates.pem \
  && echo "## Pass: copied the waagent cert to the directory common" \
  || echo "## Fail: failed to copy the waagent cert to the directory common"

sudo curl -s $BASE_URI/scripts/common/files.json --output /$PREFIX/common/files.json \
  && echo "## Pass: downloaded files.json to the directory common" \
  || echo "## Fail: failed to download files.json to the directory common"

FILES_ARRAY=$(sudo cat /$PREFIX/common/files.json | jq -r ".[] | .[]") \
  && echo "## Pass: created array of files from files.json" \
  || echo "## Fail: failed to create array of files from files.json"

for i in $FILES_ARRAY
do
  sudo curl -s "$BASE_URI"/scripts"$i" --output /"$PREFIX""$i" \
    && echo "## Pass: downloaded $BASE_URI/scripts$i to /$PREFIX$i" \
    || echo "## Fail: failed to download $BASE_URI/scripts$i to /$PREFIX$i"
done

sudo touch /$PREFIX/common/cron_tab_empty.conf \
  && echo "## Pass: created empty crontab template" \
  || echo "## Fail: failed to create empty crontab template"

sudo chmod -R 755 /$PREFIX/{jobs,common,export} \
  && echo "## Pass: add execute permissions to files in /jobs /common and /export directories" \
  || echo "## Fail: failed to add execute permissions to files in /jobs /common and /export directories"

##################
echo "############ Configure Docker"

sudo docker swarm init \ 
  && echo "## Pass: initialized Docker Swarm" \
  || echo "## Fail: failed to initialize Docker Swarm"

sudo crontab -u $LINUX_USERNAME /$PREFIX/common/cron_tab_empty.conf \
  && echo "## Pass: removed existing crontab for $LINUX_USERNAME" \
  || echo "## Pass: crontab is not yet configured for $LINUX_USERNAME"

sudo crontab -u $LINUX_USERNAME -r \
  && echo "## Pass: removed existing crontab for $LINUX_USERNAME" \
  || echo "## Fail: unable to remove crontab"

DOCKER_SERVICE_EXISTING=sudo docker service ls --format "{{.ID}}" \
  && echo "## Pass: initialized Docker Swarm" \
  || echo "## Fail: failed to initialize Docker Swarm"


sudo docker service ls > /dev/null \
  && { sudo docker service rm influxdb ; echo "## Pass: removed existing docker service influxdb" ; } \
  || echo "## Pass: docker service influxdb does not exists yet" 
    
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