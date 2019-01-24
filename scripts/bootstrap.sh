#!/bin/bash
SCRIPT_VERSION=0.1

echo "############ Date     : $(date)"
echo "############ Version  : $SCRIPT_VERSION"

echo "############ Set Argument Object"
ARGUMENTS_JSON=$1
ARGUMENTS_BLOB_ENDPOINT=$2

###################################################
#######   Requires Internet Connectivity   ########
###################################################

##################
echo "############ Installing Prerequisistes"

sudo apt-get update \
  && echo "## Pass: updated package database" \
  || { echo "## Fail: failed to update package database" ; exit 1 ; }

sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq apache2-utils \
  && echo "## Pass: prereq packages installed" \
  || { echo "## Fail: failed to install prereq packages" ; exit 1 ; }

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
  && echo "## Pass: added GPG key for Docker repository" \
  || { echo "## Fail: failed to add GPG key for Docker repository" ; exit 1 ; }

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  && echo "## Pass: added Docker repository to APT sources" \
  || { echo "## Fail: failed to add Docker repository to APT sources" ; exit 1 ; }

sudo apt-get update \
  && echo "## Pass: updated package database with Docker packages" \
  || { echo "## Fail: failed to update package database with Docker packages" ; exit 1 ; }

sudo apt-get install -y docker-ce \
  && echo "## Pass: installed docker-ce" \
  || { echo "## Fail: failed to install docker-ce" ; exit 1 ; }

##################
echo "############ Donwload docker images"	

sudo docker pull influxdb \
  && echo "## Pass: pulled influxdb image from docker hub" \
  || { echo "## Fail: failed to pull influxdb image from docker hub" ; exit 1 ; }

sudo docker pull grafana/grafana \
  && echo "## Pass: pulled grafana image from docker hub" \
  || { echo "## Fail: failed to pull grafana image from docker hub" ; exit 1 ; }

sudo docker pull microsoft/azure-cli \
  && echo "## Pass: pulled microsoft/azure-cli image from docker hub" \
  || { echo "## Fail: failed to pull microsoft/azure-cli image from docker hub" ; exit 1 ; }

sudo docker pull nginx \
  && echo "## Pass: pulled nginx image from docker hub" \
  || { echo "## Fail: failed to pull nginx image from docker hub" ; exit 1 ; }

####################################################
######   No Internet Connectivity Required   #######
####################################################

##################
echo "############ Set variables"

FQDN=${ARGUMENTS_BLOB_ENDPOINT#*.} \
  && echo "## Pass: removed storageaccountname. from blob endpoint" \
  || { echo "## Fail: failed to remove storageaccountname. from blob endpoint" ; exit 1 ; }

FQDN=${FQDN#*.} \
  && echo "## Pass: removed blob. from blob endpoint" \
  || { echo "## Fail: failed to remove blob. from blob endpoint" ; exit 1 ; }

FQDN=${FQDN%/*} \
  && echo "## Pass: removed trailing backslash from blob endpoint" \
  || { echo "## Fail: failed to remove trailing backslash from blob endpoint" ; exit 1 ; }

BASE_URI=$(echo $ARGUMENTS_JSON | jq -r ".baseUrl") \
  && echo "## Pass: set variable BASE_URI" \
  || { echo "## Fail: failed to set variable BASE_URI" ; exit 1 ; }

SUBSCRIPTION_ID=$(echo $ARGUMENTS_JSON | jq -r ".subscriptionId") \
  && echo "## Pass: set variable SUBSCRIPTION_ID" \
  || { echo "## Fail: failed to set variable SUBSCRIPTION_ID" ; exit 1 ; }

APP_ID=$(echo $ARGUMENTS_JSON | jq -r ".appId") \
  && echo "## Pass: set variable APP_ID" \
  || { echo "## Fail: failed to set variable APP_ID" ; exit 1 ; }

APP_KEY=$(echo $ARGUMENTS_JSON | jq -r ".appKey") \
  && echo "## Pass: set variable APP_KEY" \
  || { echo "## Fail: failed to set variable APP_KEY" ; exit 1 ; }

TENANT_ID=$(echo $ARGUMENTS_JSON | jq -r ".tenantId") \
  && echo "## Pass: set variable TENANT_ID" \
  || { echo "## Fail: failed to set variable TENANT_ID" ; exit 1 ; }

GRAFANA_ADMIN=$(echo $ARGUMENTS_JSON | jq -r ".grafanaPassword") \
  && echo "## Pass: set variable GRAFANA_ADMIN" \
  || { echo "## Fail: failed to set variable GRAFANA_ADMIN" ; exit 1 ; }

LINUX_USERNAME=$(echo $ARGUMENTS_JSON | jq -r ".linuxUsername") \
  && echo "## Pass: set variable LINUX_USERNAME" \
  || { echo "## Fail: failed to set variable LINUX_USERNAME" ; exit 1 ; }

##################
echo "############ Files and directories"

sudo mkdir -p /azs/{jobs,common,influxdb,grafana/{datasources,dashboards},export,nginx} \
  && echo "## Pass: created directory structure" \
  || { echo "## Fail: failed to create directory structure" ; exit 1 ; }

sudo cp /var/lib/waagent/Certificates.pem /azs/common/Certificates.pem \
  && echo "## Pass: copied the waagent cert to the directory common" \
  || { echo "## Fail: failed to copy the waagent cert to the directory common" ; exit 1 ; }

sudo curl -s $BASE_URI/scripts/common/files.json --output /azs/common/files.json \
  && echo "## Pass: downloaded files.json to the directory common" \
  || { echo "## Fail: failed to download files.json to the directory common" ; exit 1 ; }

FILES_ARRAY=$(sudo cat /azs/common/files.json | jq -r ".[] | .[]") \
  && echo "## Pass: created array of files from files.json" \
  || { echo "## Fail: failed to create array of files from files.json" ; exit 1 ; }

for i in $FILES_ARRAY
do
  sudo curl -s "$BASE_URI"/scripts"$i" --output /azs"$i" \
    && echo "## Pass: downloaded $BASE_URI/scripts$i to /azs$i" \
    || { echo "## Fail: failed to download $BASE_URI/scripts$i to /azs$i" ; exit 1 ; }
done

sudo chmod -R 755 /azs/{jobs,common,export} \
  && echo "## Pass: add execute permissions to files in /jobs /common and /export directories" \
  || { echo "## Fail: failed to add execute permissions to files in /jobs /common and /export directories" ; exit 1 ; }

##################
echo "############ Configure Docker"

sudo docker swarm init \
  && echo "## Pass: initialized Docker Swarm" \
  || echo "## Pass: Docker Swarm is already initialized"

# Remove existing services
sudo crontab -u $LINUX_USERNAME -r \
  && echo "## Pass: removed existing crontab for $LINUX_USERNAME" \
  || echo "## Pass: crontab is not yet configured for $LINUX_USERNAME"

sudo docker service rm $(sudo docker service ls --format "{{.ID}}") \
  && echo "## Pass: removed existing docker services" \
  || echo "## Pass: no exisiting docker service found"
    
sudo docker secret rm $(sudo docker secret ls --format "{{.ID}}") \
  && echo "## Pass: removed existing docker secrets" \
  || echo "## Pass: no exisiting docker secret found"

# Create secrets
printf $FQDN | sudo docker secret create fqdn - \
  && echo "## Pass: created docker secret fqdn" \
  || { echo "## Fail: failed to create docker secret fqdn" ; exit 1 ; }

printf $SUBSCRIPTION_ID | sudo docker secret create subscription_Id - \
  && echo "## Pass: created docker secret subscription_Id" \
  || { echo "## Fail: failed to create docker secret subscription_Id" ; exit 1 ; }

printf $APP_ID | sudo docker secret create app_Id - \
  && echo "## Pass: created docker secret app_Id" \
  || { echo "## Fail: failed to create docker secret app_Id" ; exit 1 ; }

printf $APP_KEY | sudo docker secret create app_Key - \
  && echo "## Pass: created docker secret app_Key" \
  || { echo "## Fail: failed to create docker secret app_Key" ; exit 1 ; }

printf $TENANT_ID | sudo docker secret create tenant_Id - \
  && echo "## Pass: created docker secret tenant_Id" \
  || { echo "## Fail: failed to create docker secret tenant_Id" ; exit 1 ; }

printf $GRAFANA_ADMIN | sudo docker secret create grafana_Admin - \
  && echo "## Pass: created docker secret grafana_Admin" \
  || { echo "## Fail: failed to create docker secret grafana_Admin" ; exit 1 ; }

sudo htpasswd -bc /azs/nginx/.htpasswd admin $GRAFANA_ADMIN \
  && echo "## Pass: created nginx password file" \
  || { echo "## Fail: failed to create nginx password file" ; exit 1 ; }

# Create overlay network
sudo docker network create --driver overlay azs \
  && echo "## Pass: created network overlay azs" \
  || echo "## Pass: network overlay azs already exists"

# Create docker services
sudo docker service create \
     --name influxdb \
     --detach \
     --restart-condition any \
     --network="azs" \
     --mount type=bind,src=/azs/influxdb,dst=/var/lib/influxdb \
     --publish published=8086,target=8086 \
     --env INFLUXDB_DB=azs \
     influxdb \
  && echo "## Pass: created docker service for influxdb" \
  || { echo "## Fail: failed to create docker service for influxdb" ; exit 1 ; }

sudo docker service create \
     --name grafana \
     --detach \
     --restart-condition any \
     --network="azs" \
     --mount type=bind,src=/azs/grafana,dst=/etc/grafana/provisioning \
     --publish published=3000,target=3000 \
     --secret grafana_Admin \
     --env GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_Admin \
     grafana/grafana \
  && echo "## Pass: created docker service for grafana" \
  || { echo "## Fail: failed to create docker service for grafana" ; exit 1 ; }

sudo docker service create \
     --name nginx \
     --detach \
     --restart-condition any \
     --network="azs" \
     --mount type=bind,src=/azs/export,dst=/azs/export \
     --mount type=bind,src=/azs/nginx/nginx.conf,dst=/etc/nginx/nginx.conf \
     --mount type=bind,src=/azs/nginx/.htpasswd,dst=/etc/nginx/.htpasswd \
     --publish published=8080,target=80 \
     nginx \
  && echo "## Pass: created docker service for nginx" \
  || { echo "## Fail: failed to create docker service for nginx" ; exit 1 ; }

# Crontab
sudo crontab -u $LINUX_USERNAME /azs/common/cron_tab.conf \
  && echo "## Pass: created crontab for $LINUX_USERNAME" \
  || { echo "## Fail: failed to create crontab for $LINUX_USERNAME" ; exit 1 ; }

# InfluxDB retention policy
curl -sX POST "http://localhost:8086/query?db=azs" --data-urlencode "q=CREATE RETENTION POLICY "azs_90days" ON "azs" DURATION 90d REPLICATION 1 SHARD DURATION 7d DEFAULT" \
  && echo "## Pass: set retention policy to 90 days" \
  || { echo "## Fail: failed to set retention policy to 90 days" ; exit 1 ; }