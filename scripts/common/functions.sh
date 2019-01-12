#!/bin/bash
FUNCTIONS_SCRIPT_VERSION=0.1

echo "## Version functions.sh  : $FUNCTIONS_SCRIPT_VERSION"

function azmon_log_field
{
  # Field name can be job (indicating the start or the completion of the full job)
  # can be the name of the task within a job (e.g. auth)
  # or can be the name of another field to add (e.g. version)
  FIELD_NAME=$1

  # Field type is either N or T.
  # N is used for a number (for creating graphs)
  # T Text needs to be escaped in the Line Protocol
  FIELD_VALUE_TYPE=$2

  # -1 indicated the job or jobtask is starting, 1 indicates its completed
  FIELD_VALUE=$3
  
  echo "## Task: azmon_log_field ${JOB_NAME} ${FIELD_NAME} ${FIELD_VALUE}"
  
  if [ "$FIELD_VALUE_TYPE" == "N" ]; then 
    curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "${JOB_NAME} ${FIELD_NAME}=${FIELD_VALUE} ${JOB_TIMESTAMP}" | grep HTTP
  fi

  if [ "$FIELD_VALUE_TYPE" == "T" ]; then
    curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "${JOB_NAME} ${FIELD_NAME}=\"${FIELD_VALUE}\" ${JOB_TIMESTAMP}" | grep HTTP  
  fi

  # If there is a fourth argument with the value fail, then exit the container completely
  if [ "$4" == "fail" ]; then
   exit 
  fi  
} 

function azmon_log_runtime
{
  TASK=$1 
  # can be job (indicating the start or the completion of the full job)
  # can be the name of the task within a job (e.g. auth)

  RUNTIME=$(( $(date --utc +%s) - $(date -d @$(($JOB_TIMESTAMP/1000000000)) +%s) ))
   
  echo "## Task: azmon_log_runtime ${JOB_NAME} ${TASK}_runtime ${RUNTIME}"
  curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "${JOB_NAME} ${TASK}_runtime=${RUNTIME} ${JOB_TIMESTAMP}" | grep HTTP 
} 

function azmon_login
{
  # Write entry in DB indicating auth is starting
  azmon_log_field N auth -1

  # Set REQUESTS_CA_BUNDLE variable with AzureStack root CA
  export REQUESTS_CA_BUNDLE=/azmon/common/Certificates.pem \
    && azmon_log_field T status auth_ca_bundle \
    || azmon_log_field T status auth_ca_bundle fail

  ## Register cloud (cloud_register)
  az cloud register -n AzureStackCloud --endpoint-resource-manager "https://$1.$(cat /run/secrets/fqdn)" \
    && azmon_log_field T status auth_cloud_register \
    || azmon_log_field T status auth_cloud_register fail

  ## Select cloud
  az cloud set -n AzureStackCloud \
    && azmon_log_field T status auth_select_cloud \
    || azmon_log_field T status auth_cloud_register fail

  ## Api Profile
  az cloud update --profile 2018-03-01-hybrid \
    && azmon_log_field T status auth_set_apiprofile \
    || azmon_log_field T status auth_set_apiprofile fail

  ## Sign in as SPN
  az login --service-principal --tenant $TENANT_ID $(cat /run/secrets/tenant_Id) -u $(cat /run/secrets/app_Id) -p $(cat /run/secrets/app_Key) \
    && azmon_log_field T status auth_login \
    || azmon_log_field T status auth_login fail
  
  # Update log with runtime for auth task
  azmon_log_runtime auth
  # Update log with completed auth task 
  azmon_log_field N auth 1
  
  return 0
}