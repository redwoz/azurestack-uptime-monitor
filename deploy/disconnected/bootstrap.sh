#!/bin/bash

ARGUMENTS_JSON=$1
ARGUMENTS_BLOB_ENDPOINT=$2

########################### Set Variables #####################################
echo "##################### Set Variables"

FQDN=${ARGUMENTS_BLOB_ENDPOINT#*.} \
  && echo "## Pass: remove storageaccountname. from blob endpoint" \
  || { echo "## Fail: remove storageaccountname. from blob endpoint" ; exit 1 ; }

FQDN=${FQDN#*.} \
  && echo "## Pass: remove blob. from blob endpoint" \
  || { echo "## Fail: remove blob. from blob endpoint" ; exit 1 ; }

FQDN=${FQDN%/*} \
  && echo "## Pass: remove trailing backslash from blob endpoint" \
  || { echo "## Fail: remove trailing backslash from blob endpoint" ; exit 1 ; }

API_PROFILE=$(echo $ARGUMENTS_JSON | jq -r ".apiProfile") \
  && echo "## Pass: set variable API_PROFILE" \
  || { echo "## Fail: set variable API_PROFILE" ; exit 1 ; }

TENANT_ID=$(echo $ARGUMENTS_JSON | jq -r ".tenantId") \
  && echo "## Pass: set variable TENANT_ID" \
  || { echo "## Fail: set variable TENANT_ID" ; exit 1 ; }

APP_ID=$(echo $ARGUMENTS_JSON | jq -r ".appId") \
  && echo "## Pass: set variable APP_ID" \
  || { echo "## Fail: set variable APP_ID" ; exit 1 ; }

APP_KEY=$(echo $ARGUMENTS_JSON | jq -r ".appKey") \
  && echo "## Pass: set variable APP_KEY" \
  || { echo "## Fail: set variable APP_KEY" ; exit 1 ; }

SUBSCRIPTION_ID=$(echo $ARGUMENTS_JSON | jq -r ".tenantSubscriptionId") \
  && echo "## Pass: set variable SUBSCRIPTION_ID" \
  || { echo "## Fail: set variable SUBSCRIPTION_ID" ; exit 1 ; }

LOCATION=$(echo $ARGUMENTS_JSON | jq -r ".location") \
  && echo "## Pass: set variable LOCATION" \
  || { echo "## Fail: set variable LOCATION" ; exit 1 ; }

UNIQUE_STRING=$(echo $ARGUMENTS_JSON | jq -r ".uniqueString") \
  && echo "## Pass: set variable UNIQUE_STRING" \
  || { echo "## Fail: set variable UNIQUE_STRING" ; exit 1 ; }

LINUX_USERNAME=$(echo $ARGUMENTS_JSON | jq -r ".linuxUsername") \
  && echo "## Pass: set variable LINUX_USERNAME" \
  || { echo "## Fail: set variable LINUX_USERNAME" ; exit 1 ; }

# Permissions

sudo cp /var/lib/waagent/Certificates.pem /azs/cli/shared/Certificates.pem \
  && echo "## Pass: copy the waagent cert to the common directory" \
  || { echo "## Fail: copy the waagent cert to the common directory" ; exit 1 ; }

sudo chmod -R 755 /azs/{common,cli/{jobs,shared,export}} \
  && echo "## Pass: set execute permissions for directories" \
  || { echo "## Fail: set execute permissions for directories" ; exit 1 ; }

sudo chmod -R 777 /azs/cli/log \
  && echo "## Pass: set write permissions for directory" \
  || { echo "## Fail: set write permissions for directory" ; exit 1 ; }

########################### Function az login and logout ######################
echo "##################### Function az login and logout"

function azs_login
{
  local FQDNHOST=$1

  export REQUESTS_CA_BUNDLE=/azs/cli/shared/Certificates.pem \
    && echo "## Pass: set REQUESTS_CA_BUNDLE with AzureStack root CA" \
    || { echo "## Fail: set REQUESTS_CA_BUNDLE with AzureStack root CA" ; exit 1 ; }

  # Set to Azure Cloud first to cleanup a profile from failed deployments
  az cloud set \
    --name AzureCloud \
  && echo "## Pass: select AzureCloud" \
  || { echo "## Fail: select cloud" ; exit 1 ; }

  # Cleanup existing profile from failed deployment
  az cloud unregister \
      --name AzureStackCloud \
  && echo "## Pass: unregister AzureStackCloud" \
  || echo "## Pass: AzureStackCloud does not exist yet" 

  az cloud register \
      --name AzureStackCloud \
      --endpoint-resource-manager "https://$FQDNHOST.$FQDN" \
      --suffix-storage-endpoint $FQDN \
      --profile $API_PROFILE \
    && echo "## Pass: register cloud" \
    || { echo "## Fail: register cloud" ; exit 1 ; }

  ## Select cloud
  az cloud set \
      --name AzureStackCloud \
    && echo "## Pass: select cloud" \
    || { echo "## Fail: select cloud" ; exit 1 ; }

  ## Sign in as SPN
  az login \
        --service-principal \
        --tenant $TENANT_ID \
        --username $APP_ID \
        --password $APP_KEY \
    && echo "## Pass: signin as service principal" \
    || { echo "## Fail: signin as service principal" ; exit 1 ; }

  ## If auth endpoint is management, then set tenantSubscriptionId for SPN
  if [ "$FQDNHOST" = "management" ]
  then
    az account set \
          --subscription $SUBSCRIPTION_ID \
      && echo "## Pass: set subscription id" \
      || { echo "## Fail: set subscription id" ; exit 1 ; }
  fi

  return 0
}

function azs_logout 
{
  az logout \
    && echo "## Pass: az logout" \
    || { echo "## Fail: az logout" ; exit 1 ; }

  az cloud set \
      --name AzureCloud \
    && echo "## Pass: select cloud" \
    || { echo "## Fail: select cloud" ; exit 1 ; }

  az cloud unregister \
        --name AzureStackCloud \
    && echo "## Pass: unregister AzureStackCloud" \
    || { echo "## Fail: unregister AzureStackCloud" ; exit 1 ; }

  return 0
}

########################### Provision Test Resources ##########################
echo "##################### Provision Test Resources"

azs_login management

az group create \
  --location $LOCATION \
  --name $UNIQUE_STRING \
  && echo "## Pass: create resource group" \
  || { echo "## Fail: create resource group" ; exit 1 ; }

az group deployment create \
  --resource-group $UNIQUE_STRING \
  --name bootstrap \
  --template-file /azs/cli/shared/mainTemplate.json \
  --parameters uniqueString=$UNIQUE_STRING \
  && echo "## Pass: deploy template" \
  || { echo "## Fail: deploy template" ; exit 1 ; }

UNIQUE_STRING_STORAGE_ACCOUNT="$UNIQUE_STRING"storage \
  && echo "## Pass: set variable UNIQUE_STRING_STORAGE_ACCOUNT" \
  || { echo "## Fail: set variable UNIQUE_STRING_STORAGE_ACCOUNT" ; exit 1 ; }

UNIQUE_STRING_STORAGE_ACCOUNT_KEY=$(az storage account keys list \
        --account-name $UNIQUE_STRING_STORAGE_ACCOUNT \
        --resource-group $UNIQUE_STRING \
        | jq -r ".[0].value") \
  && echo "## Pass: retrieve storage account key" \
  || { echo "## Fail: retrieve storage account key" ; exit 1 ; }

az storage container create \
        --name $UNIQUE_STRING \
        --account-name $UNIQUE_STRING_STORAGE_ACCOUNT \
        --account-key $UNIQUE_STRING_STORAGE_ACCOUNT_KEY \
        --public-access blob \
  && echo "## Pass: create container" \
  || { echo "## Fail: create container" ; exit 1 ; }

echo $UNIQUE_STRING > read.log \
  && echo "## Pass: create read.log" \
  || { echo "## Fail: create read.log" ; exit 1 ; }

az storage blob upload \
        --container-name $UNIQUE_STRING \
        --account-name $UNIQUE_STRING_STORAGE_ACCOUNT \
        --account-key $UNIQUE_STRING_STORAGE_ACCOUNT_KEY \
        --file read.log \
        --name read.log \
  && echo "## Pass: upload blob" \
  || { echo "## Fail: upload blob" ; exit 1 ; }

azs_logout

########################### Azure Bridge SubscriptionId #######################
echo "##################### Azure Bridge SubscriptionId"

azs_login adminmanagement

function azs_bridge
{
  BRIDGE_ACTIVATION_ID=$(az resource list \
        --resource-type "Microsoft.AzureBridge.Admin/activations" \
        | jq -r ".[0].id") \
    && echo "## Pass: get activation id" \
    || { echo "## Fail: get activation id" ; exit 1 ; }

  if [ $BRIDGE_ACTIVATION_ID = "null" ]
  then
    echo "## Pass: Azure Stack not registered"
    BRIDGE_SUBSCRIPTION_ID="azurestacknotregistered"
    return 0
  fi

  BRIDGE_REGISTRATION_ID=$(az resource show \
        --ids $BRIDGE_ACTIVATION_ID \
        | jq -r ".properties.azureRegistrationResourceIdentifier") \
    && echo "## Pass: get registration id" \
    || { echo "## Fail: get registration id" ; exit 1 ; }

  # Remove leading "/"
  BRIDGE_SUBSCRIPTION_ID=${BRIDGE_REGISTRATION_ID#*/} \
    && echo "## Pass: remove leading /" \
    || { echo "## Fail: remove leading /" ; exit 1 ; }

  # Remove "sbscriptions/"
  BRIDGE_SUBSCRIPTION_ID=${BRIDGE_SUBSCRIPTION_ID#*/} \
    && echo "## Pass: remove subscriptions/" \
    || { echo "## Fail: remove subscriptions/" ; exit 1 ; }

  # Remove trailing path from subscription id
  BRIDGE_SUBSCRIPTION_ID=${BRIDGE_SUBSCRIPTION_ID%%/*} \
    && echo "## Pass: remove trailing path from subscription id" \
    || { echo "## Fail: remove trailing path from subscription id" ; exit 1 ; }
}

azs_bridge

azs_logout

########################### Remove Existing Services ##########################
echo "##################### Remove Existing Services"

sudo docker swarm init \
  && echo "## Pass: initialize Docker Swarm" \
  || echo "## Pass: Docker Swarm is already initialized"

sudo crontab -u $LINUX_USERNAME -r \
  && echo "## Pass: remove existing crontab for $LINUX_USERNAME" \
  || echo "## Pass: crontab is not yet configured for $LINUX_USERNAME"

sudo docker service rm $(sudo docker service ls --format "{{.ID}}") \
  && echo "## Pass: removed existing docker services" \
  || echo "## Pass: no exisiting docker service found"
    
sudo docker secret rm $(sudo docker secret ls --format "{{.ID}}") \
  && echo "## Pass: removed existing docker secrets" \
  || echo "## Pass: no exisiting docker secret found"

########################### Create Services ###################################
echo "##################### Create Services"

sudo docker network create --driver overlay azs \
  && echo "## Pass: create network overlay azs" \
  || echo "## Pass: network overlay azs already exists"

echo $ARGUMENTS_JSON | jq -r ".grafanaPassword" | sudo docker secret create grafana - \
  && echo "## Pass: create docker secret grafana" \
  || { echo "## Fail: create docker secret grafana" ; exit 1 ; }

ARGUMENTS_JSON=$(echo $ARGUMENTS_JSON \
      | jq --arg X $FQDN '. + {fqdn: $X}') \
  && echo "## Pass: add fqdn" \
  || { echo "## Fail: add fqdn" ; exit 1 ; }

ARGUMENTS_JSON=$(echo $ARGUMENTS_JSON \
      | jq --arg X $BRIDGE_SUBSCRIPTION_ID '. + {azureSubscriptionId: $X}') \
  && echo "## Pass: add azureSubscriptionId" \
  || { echo "## Fail: add azureSubscriptionId" ; exit 1 ; }

ARGUMENTS_JSON=$(echo $ARGUMENTS_JSON \
      | jq --arg X $(sudo cat /azs/common/config.json | jq -r ".version.script") '. + {scriptVersion: $X}') \
  && echo "## Pass: add fqdn" \
  || { echo "## Fail: add fqdn" ; exit 1 ; }

echo $ARGUMENTS_JSON | sudo docker secret create cli - \
  && echo "## Pass: created docker secret cli" \
  || { echo "## Fail: created docker secret cli" ; exit 1 ; }

# InfluxDB
sudo docker service create \
     --name influxdb \
     --detach \
     --restart-condition any \
     --network azs \
     --mount type=bind,src=/azs/influxdb,dst=/var/lib/influxdb \
     --publish published=8086,target=8086 \
     --env INFLUXDB_DB=azs \
     influxdb:$INFLUXDB_VERSION \
  && echo "## Pass: create docker service for influxdb" \
  || { echo "## Fail: create docker service for influxdb" ; exit 1 ; }

# Grafana
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
     --secret grafana \
     --env GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana \
     grafana/grafana:$GRAFANA_VERSION \
  && echo "## Pass: create docker service for grafana" \
  || { echo "## Fail: create docker service for grafana" ; exit 1 ; }

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

# Crontab
sudo crontab -u $LINUX_USERNAME /azs/common/cron_tab.conf \
  && echo "## Pass: create crontab for $LINUX_USERNAME" \
  || { echo "## Fail: create crontab for $LINUX_USERNAME" ; exit 1 ; }

# InfluxDB retention policy
curl -sX POST "http://localhost:8086/query?db=azs" \
      --data-urlencode "q=CREATE RETENTION POLICY "azs_90days" ON "azs" DURATION 90d REPLICATION 1 SHARD DURATION 7d DEFAULT" \
  && echo "## Pass: set retention policy to 90 days" \
  || { echo "## Fail: set retention policy to 90 days" ; exit 1 ; }