#!/bin/bash
FUNCTIONS_SCRIPT_VERSION=0.2

echo "############ Date       : $(date)"
echo "############ Job name   : $JOB_NAME"
echo "############ Version    : $SCRIPT_VERSION"
echo "############ Functions  : $FUNCTIONS_SCRIPT_VERSION"

function azs_log_field
{
  # Field type is either N or T.
  # N is used for a number (for creating graphs)
  # T Text needs to be escaped in the Line Protocol
  local FIELD_VALUE_TYPE=$1

  # Field name can be job (indicating the start or the completion of the full job)
  # can be the name of the task within a job (e.g. auth)
  # or can be the name of another field to add (e.g. version)
  local FIELD_NAME=$2

  # -1 indicated the job or jobtask is starting, 1 indicates its completed
  local FIELD_VALUE=$3
  
  if [ "$FIELD_VALUE_TYPE" == "N" ]; then 
    echo "## Task: azs_log_field N ${JOB_NAME} ${FIELD_NAME} ${FIELD_VALUE}"
    curl -s -i -XPOST "http://influxdb:8086/write?db=azs&precision=s" --data-binary "${JOB_NAME} ${FIELD_NAME}=${FIELD_VALUE} ${JOB_TIMESTAMP}" | grep HTTP
  fi

  if [ "$FIELD_VALUE_TYPE" == "T" ]; then
    echo "## Task: azs_log_field T ${JOB_NAME} ${FIELD_NAME} ${FIELD_VALUE}"
    curl -s -i -XPOST "http://influxdb:8086/write?db=azs&precision=s" --data-binary "${JOB_NAME} ${FIELD_NAME}=\"${FIELD_VALUE}\" ${JOB_TIMESTAMP}" | grep HTTP  
  fi

  # If there is a fourth argument with the value fail, then exit the container completely
  if [ "$4" == "fail" ]; then
   exit 
  fi  
} 

function azs_log_runtime
{
  local TASK=$1 
  # can be job (indicating the start or the completion of the full job)
  # can be the name of the task within a job (e.g. auth)
  local STARTTIME=$2

  local RUNTIME=$(( $(date --utc +%s) - $STARTTIME ))
   
  echo "## Task: azs_log_runtime ${JOB_NAME} ${TASK}_runtime ${RUNTIME}"
  curl -s -i -XPOST "http://influxdb:8086/write?db=azs&precision=s" --data-binary "${JOB_NAME} ${TASK}_runtime=${RUNTIME} ${JOB_TIMESTAMP}" | grep HTTP 
} 

function azs_task_start
{
  # Action = probe, auth, create, read, update or delete
  local ACTION=$1
  
  echo "## Task start: $JOB_NAME $ACTION"
  # Set the starttime for the task
  START_TIME=$(date --utc +%s)

  # Write entry in DB indicating auth is starting
  azs_log_field N $ACTION 0
}

function azs_task_end
{
  # Action = probe, create, read, update or delete
  local ACTION=$1

  echo "## Task end: $JOB_NAME $ACTION"
  # Set the starttime for the task
  azs_log_runtime $ACTION $START_TIME
  azs_log_field N $ACTION 100
}

function azs_job_end
{
  echo "## Job complete: $JOB_NAME"
  # Set the starttime for the task
  azs_log_runtime job $JOB_TIMESTAMP
  azs_log_field N job 100
}

function azs_login
{
  # Set REQUESTS_CA_BUNDLE variable with AzureStack root CA
  export REQUESTS_CA_BUNDLE=/azs/common/Certificates.pem \
    && azs_log_field T status auth_ca_bundle \
    || azs_log_field T status auth_ca_bundle fail

  ## Register cloud (cloud_register)
  az cloud register -n AzureStackCloud --endpoint-resource-manager "https://$1.$(cat /run/secrets/fqdn)" \
    && azs_log_field T status auth_cloud_register \
    || azs_log_field T status auth_cloud_register fail

  ## Select cloud
  az cloud set -n AzureStackCloud \
    && azs_log_field T status auth_select_cloud \
    || azs_log_field T status auth_cloud_register fail

  ## Set Api Profile
  az cloud update --suffix-storage-endpoint "$(cat /run/secrets/fqdn)" \
    && azs_log_field T status auth_set_storage_endpoint \
    || azs_log_field T status auth_set_storage_endpoint fail

  ## Set Blob Endpoint
  az cloud update --profile 2018-03-01-hybrid \
    && azs_log_field T status auth_set_apiprofile \
    || azs_log_field T status auth_set_apiprofile fail

  ## Sign in as SPN
  az login --service-principal --tenant $(cat /run/secrets/tenantId) -u $(cat /run/secrets/appId) -p $(cat /run/secrets/appKey) \
    && azs_log_field T status auth_login \
    || azs_log_field T status auth_login fail
  
  return 0
}

# Add script versions to influxdb entry
azs_log_field N script_version $SCRIPT_VERSION
azs_log_field N functions_version $FUNCTIONS_SCRIPT_VERSION