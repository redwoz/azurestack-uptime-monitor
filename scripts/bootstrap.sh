#!/bin/bash
SCRIPT_VERSION=0.5

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

sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq \
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

STORAGE_ACCOUNT=${ARGUMENTS_BLOB_ENDPOINT%%.*} \
  && echo "## Pass: removed fqdn/ from blob endpoint" \
  || { echo "## Fail: failed to remove fqdn/ from blob endpoint" ; exit 1 ; }

STORAGE_ACCOUNT=${STORAGE_ACCOUNT##*/} \
  && echo "## Pass: retrieved storageaccountname from blob endpoint" \
  || { echo "## Fail: failed to retrieve storageaccountname from blob endpoint" ; exit 1 ; }

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

UNIQUE_STRING=$(echo $ARGUMENTS_JSON | jq -r ".uniqueString") \
  && echo "## Pass: set variable UNIQUE_STRING" \
  || { echo "## Fail: failed to set variable UNIQUE_STRING" ; exit 1 ; }

##################
echo "############ Files and directories"

sudo mkdir -p /azs/{jobs,common,influxdb,grafana/{database,datasources,dashboards},export,log,bridge} \
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

sudo chmod -R 777 /azs/log \
  && echo "## Pass: add write permissions to azs/log directory" \
  || { echo "## Fail: failed to add write permissions to azs/log directory" ; exit 1 ; }

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

printf $STORAGE_ACCOUNT | sudo docker secret create storageAccount - \
  && echo "## Pass: created docker secret storageAccount" \
  || { echo "## Fail: failed to create docker secret storageAccount" ; exit 1 ; }

printf $SUBSCRIPTION_ID | sudo docker secret create tenantSubscriptionId - \
  && echo "## Pass: created docker secret tenantSubscriptionId" \
  || { echo "## Fail: failed to create docker secret tenantSubscriptionId" ; exit 1 ; }

printf $APP_ID | sudo docker secret create appId - \
  && echo "## Pass: created docker secret appId" \
  || { echo "## Fail: failed to create docker secret appId" ; exit 1 ; }

printf $APP_KEY | sudo docker secret create appKey - \
  && echo "## Pass: created docker secret appKey" \
  || { echo "## Fail: failed to create docker secret appKey" ; exit 1 ; }

printf $TENANT_ID | sudo docker secret create tenantId - \
  && echo "## Pass: created docker secret tenantId" \
  || { echo "## Fail: failed to create docker secret tenantId" ; exit 1 ; }

printf $GRAFANA_ADMIN | sudo docker secret create grafanaAdmin - \
  && echo "## Pass: created docker secret grafanaAdmin" \
  || { echo "## Fail: failed to create docker secret grafanaAdmin" ; exit 1 ; }

printf $UNIQUE_STRING | sudo docker secret create uniqueString - \
  && echo "## Pass: created docker secret uniqueString" \
  || { echo "## Fail: failed to create docker secret uniqueString" ; exit 1 ; }

printf $BASE_URI | sudo docker secret create baseUrl - \
  && echo "## Pass: created docker secret uniqueString" \
  || { echo "## Fail: failed to create docker secret uniqueString" ; exit 1 ; }

# Create overlay network
sudo docker network create --driver overlay azs \
  && echo "## Pass: created network overlay azs" \
  || echo "## Pass: network overlay azs already exists"

# Create docker services
sudo docker service create \
     --name influxdb \
     --detach \
     --restart-condition any \
     --network azs \
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
     --network azs \
     --user $(sudo id -u) \
     --mount type=bind,src=/azs/grafana/database,dst=/var/lib/grafana \
     --mount type=bind,src=/azs/grafana/datasources,dst=/etc/grafana/provisioning/datasources \
     --mount type=bind,src=/azs/grafana/dashboards,dst=/etc/grafana/provisioning/dashboards \
     --publish published=3000,target=3000 \
     --secret grafanaAdmin \
     --env GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafanaAdmin \
     grafana/grafana \
  && echo "## Pass: created docker service for grafana" \
  || { echo "## Fail: failed to create docker service for grafana" ; exit 1 ; }

# Wait for InfluxDB http api to respond
X=15
while [ $X -ge 1 ]
do
  curl -s "http://localhost:8086/ping"
  if [ $? = 0 ]; then break; fi
  echo "Waiting for influxdb http api to respond. $X seconds"
  sleep 1s
  X=$(( $X - 1 ))
  if [ $X = 0 ]; then { echo "## Fail: influxdb http api not responding" ; exit 1 ; }; fi
done

# Create one time service to get Azure subscription from the registration
JOB_NAME=srv_bootstrap_admin
JOB_TIMESTAMP=$(date --utc +%s)

sudo docker service create \
     --name $JOB_NAME \
     --label timestamp=$JOB_TIMESTAMP \
     --detach \
     --restart-condition none \
     --network="azs" \
     --mount type=bind,src=/azs/common,dst=/azs/common \
     --mount type=bind,src=/azs/jobs,dst=/azs/jobs \
     --mount type=bind,src=/azs/bridge,dst=/azs/bridge \
     --env JOB_NAME=$JOB_NAME \
     --env JOB_TIMESTAMP=$JOB_TIMESTAMP \
     --secret fqdn \
     --secret appId \
     --secret appKey \
     --secret tenantId \
     microsoft/azure-cli \
     /azs/jobs/srv_bootstrap_admin.sh \
  && curl -s -i -XPOST "http://localhost:8086/write?db=azs&precision=s" --data-binary "${JOB_NAME} job=0,status=\"docker_service_created\" ${JOB_TIMESTAMP}" | grep HTTP \
  || echo "Unable to create docker service"

# Wait for container to start
Y=15
while [ $Y -ge 1 ]
do
  CONTAINERID=$(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}")
  if [ $CONTAINERID <> 0 ]; then break; fi
  echo "Waiting for container to start. $Y seconds"
  sleep 1s
  Y=$(( $Y - 1 ))
  if [ $Y = 0 ]; then { echo "## Fail: srv_bootstrap_admin container did not start" ; exit 1 ; }; fi
done

# Wait for one time service to exit and delete it.
sudo docker wait $(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}") \
  && echo "## Pass: waited for docker service srv_bootstrap_admin" \
  || { echo "## Fail: failed to wait for docker service srv_bootstrap_admin" ; exit 1 ; }

# Remove docker service srv_bootstrap_admin
sudo docker service rm $JOB_NAME \
  && echo "## Pass: removed docker service srv_bootstrap_admin" \
  || { echo "## Fail: failed to remove docker service srv_bootstrap_admin" ; exit 1 ; }

# Get subscription from local mount
AZURE_SUBSCRIPTION_ID=$(cat /azs/bridge/subscriptionid) \
  && echo "## Pass: retrieved azure subscriptionid from /azs/bridge/subscriptionid" \
  || { echo "## Fail: unable to retrieve azure subscriptionid from /azs/bridge/subscriptionid" ; exit 1 ; }

# Create secret with bridge subscriptionid
printf $AZURE_SUBSCRIPTION_ID | sudo docker secret create azureSubscriptionId - \
  && echo "## Pass: created docker secret azureSubscriptionId" \
  || { echo "## Fail: failed to create docker secret azureSubscriptionId" ; exit 1 ; }

# Remove folder and content
sudo rm -r /azs/bridge \
  && echo "## Pass: removed /azs/bridge" \
  || { echo "## Fail: unable to remove /azs/bridge" ; exit 1 ; }

# Create one time service to deploy readTemplate
JOB_NAME=srv_bootstrap_tenant
JOB_TIMESTAMP=$(date --utc +%s)

sudo docker service create \
     --name $JOB_NAME \
     --label timestamp=$JOB_TIMESTAMP \
     --detach \
     --restart-condition none \
     --network="azs" \
     --mount type=bind,src=/azs/common,dst=/azs/common \
     --mount type=bind,src=/azs/jobs,dst=/azs/jobs \
     --mount type=bind,src=/azs/bridge,dst=/azs/bridge \
     --env JOB_NAME=$JOB_NAME \
     --env JOB_TIMESTAMP=$JOB_TIMESTAMP \
     --secret fqdn \
     --secret appId \
     --secret appKey \
     --secret tenantId \
     --secret tenantSubscriptionId \
     --secret uniqueString \
     --secret baseUrl \
     microsoft/azure-cli \
     /azs/jobs/srv_bootstrap_tenant.sh \
  && curl -s -i -XPOST "http://localhost:8086/write?db=azs&precision=s" --data-binary "${JOB_NAME} job=0,status=\"docker_service_created\" ${JOB_TIMESTAMP}" | grep HTTP \
  || echo "Unable to create docker service"

# Wait for container to start
Y=15
while [ $Y -ge 1 ]
do
  CONTAINERID=$(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}")
  if [ $CONTAINERID <> 0 ]; then break; fi
  echo "Waiting for container to start. $Y seconds"
  sleep 1s
  Y=$(( $Y - 1 ))
  if [ $Y = 0 ]; then { echo "## Fail: srv_bootstrap_tenant container did not start" ; exit 1 ; }; fi
done

# Wait for one time service to exit and delete it.
sudo docker wait $(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}") \
  && echo "## Pass: waited for docker service srv_bootstrap_tenant" \
  || { echo "## Fail: failed to wait for docker service srv_bootstrap_tenant" ; exit 1 ; }

# Remove docker service srv_bootstrap_tenant
sudo docker service rm $JOB_NAME \
  && echo "## Pass: removed docker service srv_bootstrap_tenant" \
  || { echo "## Fail: failed to remove docker service srv_bootstrap_tenant" ; exit 1 ; }

# Crontab
sudo crontab -u $LINUX_USERNAME /azs/common/cron_tab.conf \
  && echo "## Pass: created crontab for $LINUX_USERNAME" \
  || { echo "## Fail: failed to create crontab for $LINUX_USERNAME" ; exit 1 ; }

# InfluxDB retention policy
curl -sX POST "http://localhost:8086/query?db=azs" --data-urlencode "q=CREATE RETENTION POLICY "azs_90days" ON "azs" DURATION 90d REPLICATION 1 SHARD DURATION 7d DEFAULT" \
  && echo "## Pass: set retention policy to 90 days" \
  || { echo "## Fail: failed to set retention policy to 90 days" ; exit 1 ; }