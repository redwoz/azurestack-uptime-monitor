#!/bin/bash
SCRIPT_VERSION=0.3

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################# Task: Export ################################
azs_task_start export

# Get the current year
CSV_YEAR=$(date --utc +%y)
# Get last week and return two digits
CSV_WEEK=0$(( $(date --utc +%U) - 1 ))
CSV_WEEK="${CSV_WEEK: -2}"
# Set filename
CSV_FILE_NAME=$(cat /run/secrets/azureSubscriptionId)-y${CSV_YEAR}w${CSV_WEEK}

# First week of the year
CSV_WEEK_NUM_OF_JAN_1=$(date --utc -d ${CSV_YEAR}-01-01 +%U)
CSV_WEEK_DAY_OF_JAN_1=$(date --utc -d ${CSV_YEAR}-01-01 +%u)

# Start of the first week of the year
if ((WEEK_DAY_OF_JAN_1)); then
    CSV_FIRST_SUNDAY_EPOCH=$(date --utc -d ${CSV_YEAR}-01-01 -D "%y-%m-%d" +%s)
else
    CSV_FIRST_SUNDAY_EPOCH=$(date --utc -d ${CSV_YEAR}-01-$((01 + (7 - CSV_WEEK_DAY_OF_JAN_1) )) -D "%y-%m-%d" +%s)
fi

# One week of seconds is 60s x 60m x 24h x 7d = 604800s
# To get the last week in epoch
# StartTime : Add  weeks number (default value = last week) multiplied by seconds, to the first day of the year
CSV_DATE_START=$(( CSV_FIRST_SUNDAY_EPOCH + $(( CSV_WEEK * 604800 )) ))
# Endtime : Add the weeks number (current week number) multiplied by seconds, minus one second, to the first day of the year
CSV_DATE_END=$(( CSV_FIRST_SUNDAY_EPOCH + $(( (( CSV_WEEK + 1 ) * 604800 ) - 1 )) ))

# Export data to file
curl -G 'http://influxdb:8086/query?db=azs&precision=s' \
      --data-urlencode "q=SELECT * FROM /.*/ where time >= $CSV_DATE_START and time <= $CSV_DATE_END" \
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

