#!/bin/bash

function azmon_log_job
{
  TASK=$1 
  # Can be job (indicating the start or the completion of the full job)
  # or can be the name of the task within a job (e.g. auth)
  BIT=$2
  # The bit is either 0 or 1
  # 0 indicated the job or jobtask is starting, 1 indicates its completed

  echo "# azmon_log_job $JOB_NAME_$TASK_$BIT"
  curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME $TASK=$BIT $JOB_TIMESTAMP" | grep HTTP

  # If the job or job task has completed, add a field with the task runtime 
  if [ $BIT = 1 ]; then
   CURRENT_TIMESTAMP=$(date --utc +%s%N)
   RUNTIME=$(( ($JOB_TIMESTAMP-$CURRENT_TIMESTAMP)/60000000000 ))

   echo "# azmon_log_job $JOB_NAME_$TASK_runtime_$RUNTIME"
   curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME $TASK_runtime=$RUNTIME $JOB_TIMESTAMP" | grep HTTP
  fi  

} 

function azmon_log_status 
{
  TASK=$1 # Name of the job or jobtask being executed
  STATUS=$2 # Status is either pass or fail

  echo "# azmon_log_status $JOB_NAME_$STATUS_$TASK"
  curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME status=\"$STATUS_$TASK\" $JOB_TIMESTAMP" | grep HTTP
  if [ $STATUS = "fail" ]; then
   exit 
  fi  
} 

function azmon_login
{
  # Write entry in DB indicating auth is starting
  azmon_log_job auth 0

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
  
  azmon_log_job auth 1
  return 0
}