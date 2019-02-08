#!/bin/bash
SCRIPT_VERSION=0.5

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################## Task: Auth #################################
azs_task_start auth

# Login to Azure Stack cloud 
# Provide argument "adminmanagement" for authenticating to admin endpoint
# Provide argument "management" for authenticating to tenant endpoint
azs_login management

azs_task_end auth
###################### Task: Create Target RG and Template ####################
azs_task_start create

# Get location from FQDN
FQDN=$(cat /run/secrets/fqdn)
LOCATION=${FQDN%%.*}

# Create the resource group if it doesn't already exist
az group create \
  --location $LOCATION \
  --name $(cat /run/secrets/uniqueString) \
  && azs_log_field T status create_container_log \
  || azs_log_field T status create_container_log fail

az group deployment create \
  --resource-group $(cat /run/secrets/uniqueString) \
  --name bootstrap \
  --template-uri "$(cat /run/secrets/baseUrl)"/linked/readTemplate.json \
  --parameters uniqueString=$(cat /run/secrets/uniqueString) \
  && azs_log_field T status create_container_log \
  || azs_log_field T status create_container_log fail


# Create a container and a blob to read
STORAGE_ACCOUNT_NAME="$(cat /run/secrets/uniqueString)"storage \
  && azs_log_field T status create_container_log \
  || azs_log_field T status create_container_log fail

# Get keys from storage account
STORAGE_ACCOUNT_KEY=$(az storage account keys list \
        --account-name $STORAGE_ACCOUNT_NAME \
        --resource-group $(cat /run/secrets/uniqueString) \
        | jq -r ".[0].value") \
  && azs_log_field T status get_storage_account_key \
  || azs_log_field T status get_storage_account_key fail

# Create container (if exists? with exisisting data?)
az storage container create \
        --name test \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key $STORAGE_ACCOUNT_KEY \
        --public-access blob \
  && azs_log_field T status create_container_log \
  || azs_log_field T status create_container_log fail

# Create file to upload
echo $(cat /run/secrets/uniqueString) > read.log \
  && azs_log_field T status create_container_log \
  || azs_log_field T status create_container_log fail

# Upload file to container
az storage blob upload \
        --container-name test \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key $STORAGE_ACCOUNT_KEY \
        --file read.log \
        --name read.log \
  && azs_log_field T status upload_log_to_blob \
  || azs_log_field T status upload_log_to_blob fail

azs_task_end create
############################### Job: Complete #################################
azs_job_end