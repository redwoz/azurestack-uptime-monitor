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
################################# Task: Upload ################################
azs_task_start upload

# Get Storage Account
STORAGE_ACCOUNT=$(az storage account list \
        --query "[?name=='$(cat /run/secrets/storageAccount)']") \
  && azs_log_field T status get_storage_account \
  || azs_log_field T status get_storage_account fail

# Get keys from storage account
STORAGE_ACCOUNT_KEY=$(az storage account keys list \
        --account-name $(cat /run/secrets/storageAccount) \
        --resource-group $(echo $STORAGE_ACCOUNT | jq -r ".[].resourceGroup") \
        | jq -r ".[0].value") \
  && azs_log_field T status get_storage_account_key \
  || azs_log_field T status get_storage_account_key fail

# Create container
az storage container create \
        --name log \
        --account-name $(cat /run/secrets/storageAccount) \
        --account-key $STORAGE_ACCOUNT_KEY \
  && azs_log_field T status create_container_log \
  || azs_log_field T status create_container_log fail

# Create container
az storage container create \
        --name csv \
        --account-name $(cat /run/secrets/storageAccount) \
        --account-key $STORAGE_ACCOUNT_KEY \
  && azs_log_field T status create_container_csv \
  || azs_log_field T status create_container_csv fail

# For each file in /azs/export > upload to container
az storage blob upload-batch \
        --destination log \
        --account-name $(cat /run/secrets/storageAccount) \
        --account-key $STORAGE_ACCOUNT_KEY \
        --source /azs/log \
  && azs_log_field T status upload_log_to_blob \
  || azs_log_field T status upload_log_to_blob fail

# For each file in /azs/log > upload to container, overwrite existing
az storage blob upload-batch \
        --destination csv \
        --account-name $(cat /run/secrets/storageAccount) \
        --account-key $STORAGE_ACCOUNT_KEY \
        --source /azs/export \
  && azs_log_field T status upload_csv_to_blob \
  || azs_log_field T status upload_csv_to_blob fail

azs_task_end upload
############################### Job: Complete #################################
azs_job_end

