#!/bin/bash
SCRIPT_VERSION=0.3

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################# Task: Export ################################
azs_task_start export

# To specify a specific to export run ./export_csv.sh year week
# E.g. /export_csv.sh 2019 5
# If no argumetns are passed the script exports last weeks data
YEAR=${$1:-$(date --utc +%G)}
WEEK=${$2:-$(( $(date --utc +%V) - 1 ))}
ONE_DAY_IN_SEC=86400

# Base Epoch date for year and week in seconds 
EPOCH_BASE_IN_SEC=$((  \
    $(date --utc -d "$YEAR-01-01" +%s) \
    + $(( \
        (( $WEEK * 7 + 1 - $(date -d "$YEAR-01-04" +%w ) - 3 )) \
        * $ONE_DAY_IN_SEC \
    )) \
    - $(( 2 * $ONE_DAY_IN_SEC )) \
))

# Add one day to base for start
EPOCH_START_IN_SEC=$(( \
    $EPOCH_BASE_IN_SEC + $(( 1 * $ONE_DAY_IN_SEC )) \
))

# Add 8 days minus 1 sec for end 
EPOCH_END_IN_SEC=$(( \
    $EPOCH_BASE_IN_SEC + $(( 8 * $ONE_DAY_IN_SEC )) - 1 \
))

# Set filename
WEEK_FMT=0$WEEK
WEEK_FMT="${WEEK_FMT: -2}"
CSV_FILE_NAME=$(cat /run/secrets/azureSubscriptionId)-y${YEAR}w${WEEK}

# Export data to file
curl -G 'http://influxdb:8086/query?db=azs' \
      --data-urlencode "q=SELECT * FROM /.*/ where time >= ${EPOCH_START_IN_SEC}s and time <= ${EPOCH_END_IN_SEC}s" \
      -H "Accept: application/csv" \
      -o /azs/export/$CSV_FILE_NAME.csv \
  && azs_log_field T status export_csv_to_file \
  || azs_log_field T status export_csv_to_file fail

azs_task_end export
################################## Task: Auth #################################
azs_task_start auth

# Login to Azure Stack cloud 
# Provide argument "adminmanagement" for authenticating to admin endpoint
# Provide argument "management" for authenticating to tenant endpoint
azs_login management

azs_task_end auth
################################# Task: Upload ################################
azs_task_start upload

# Create storage account (if exists? with exisisting data?)
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

# Create container (if exists? with exisisting data?)
az storage container create \
        --name csv \
        --account-name $(cat /run/secrets/storageAccount) \
        --account-key $STORAGE_ACCOUNT_KEY \
  && azs_log_field T status create_storage_container \
  || azs_log_field T status create_storage_container fail

# For each file in /azs/export > upload to container (if exists? with exisisting data?)
az storage blob upload-batch \
        --destination csv \
        --account-name $(cat /run/secrets/storageAccount) \
        --account-key $STORAGE_ACCOUNT_KEY \
        --source /azs/export \
  && azs_log_field T status upload_files_to_blob \
  || azs_log_field T status upload_files_to_blob fail

#azs_task_end upload
############################### Job: Complete #################################
azs_job_end

