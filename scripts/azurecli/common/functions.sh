#!/bin/bash
FUNCTIONS_SCRIPT_VERSION=0.1

echo "## Version functions.sh  : $FUNCTIONS_SCRIPT_VERSION"

function azmon_log_field
{
  FIELD_NAME=$1 
  # can be job (indicating the start or the completion of the full job)
  # can be the name of the task within a job (e.g. auth)
  # or can be the name of another field to add (e.g. version)
  FIELD_VALUE=$2
  # -1 indicated the job or jobtask is starting, 1 indicates its completed

  echo "## Task: azmon_log_job ${JOB_NAME} ${FIELD_NAME} ${FIELD_VALUE}"
  curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "${JOB_NAME} ${FIELD_NAME}=${FIELD_VALUE} ${JOB_TIMESTAMP}" | grep HTTP
} 

function azmon_log_status
{
  TASK=$1 # Name of the job or jobtask being executed
  STATUS=$2 # Status is either pass or fail

  echo "## Task: azmon_log_status ${JOB_NAME} ${STATUS} ${TASK}"
  curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "${JOB_NAME} status=\"${STATUS}_${TASK}\" ${JOB_TIMESTAMP}" | grep HTTP
  if [ $STATUS = "fail" ]; then
   exit 
  fi  
} 

function azmon_log_runtime
{
  TASK=$1 
  # can be job (indicating the start or the completion of the full job)
  # can be the name of the task within a job (e.g. auth)

  RUNTIME=$(( $(date --utc +%s) - $(date -d @$(($JOB_TIMESTAMP/1000000000)) +%s) ))
   
  echo "## Task: azmon_log_job ${JOB_NAME} ${TASK}_runtime ${RUNTIME}"
  curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "${JOB_NAME} ${TASK}_runtime=${RUNTIME} ${JOB_TIMESTAMP}" | grep HTTP 
} 

function azmon_login
{
  # Write entry in DB indicating auth is starting
  azmon_log_field auth -1

  # Set REQUESTS_CA_BUNDLE variable with AzureStack root CA
  export REQUESTS_CA_BUNDLE=/azmon/azurecli/common/Certificates.pem \
    && azmon_log_status auth_ca_bundle pass \
    || azmon_log_status auth_ca_bundle fail

  ## Register cloud (cloud_register)
  az cloud register -n AzureStackCloud --endpoint-resource-manager "https://$1.$(cat /run/secrets/fqdn)" \
    && azmon_log_status auth_cloud_register pass \
    || azmon_log_status auth_cloud_register fail

  ## Select cloud
  az cloud set -n AzureStackCloud \
    && azmon_log_status auth_select_cloud pass  \
    || azmon_log_status auth_select_cloud fail

  ## Api Profile
  az cloud update --profile 2018-03-01-hybrid \
    && azmon_log_status auth_set_apiprofile pass \
    || azmon_log_status auth_set_apiprofile fail

  ## Get activeDirectoryResourceId
  TENANT_URI=$(az cloud show -n AzureStackCloud | jq -r ".endpoints.activeDirectoryResourceId") \
    && azmon_log_status auth_get_resourceid_uri pass \
    || azmon_log_status auth_get_resourceid_uri fail

  ## Get TenantID by selecting value after the last /
  TENANT_ID=${TENANT_URI##*/} \
    && azmon_log_status auth_get_tenantid pass \
    || azmon_log_status auth_get_tenantid fail

  ## Sign in as SPN
  az login --service-principal --tenant $TENANT_ID -u $(cat /run/secrets/app_Id) -p $(cat /run/secrets/app_Key) \
    && azmon_log_status auth_login pass \
    || azmon_log_status auth_login fail
  
  # Update log with runtime for auth task
  azmon_log_runtime auth
  # Update log with completed auth task 
  azmon_log_field auth 1
  
  return 0
}