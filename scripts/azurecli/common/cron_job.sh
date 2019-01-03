#!/bin/bash

echo "=========== Job arguments"
JOB_NAME=$1
JOB_SCRIPT=$2
JOB_TIMESTAMP=$(date --utc +%s%N)

function azmon_existing_service_remove
{
    # Is there an existing service?
    sudo docker service inspect $JOB_NAME > /dev/null \
      && echo "Service $JOB_NAME exists" \
      || { echo "There is no service with the name $JOB_NAME" ; return 0 ; }

    # Get the timestamp from the existing serivce 
    EXISTING_SERVICE_TIMESTAMP=$(sudo docker service inspect $JOB_NAME --format='{{.Spec.Labels.timestamp}}') \
      && echo "Retrieved timestamp from existing service" \
      || echo "Unable to retrieve timestamp from existing service"

    # Check if existing serivce task is still running 
    EXISTING_SERVICE_TASK_STATUS=$(sudo docker service ps $JOB_NAME --format "{{.CurrentState}}") \
      && echo "Retrieved Docker Service task status" \
      || echo "Unable to retrieve Docker Service task status"

    # If existing service task is still running, update record in DB (based on existing TIMESTAMP)
    [[ $TASK_STATUS == Running* ]] \
      && curl -s -i -XPOST "http://localhost:8086/write?db=azmon" --data-binary "$JOB_NAME job=0,job_status=\"exceeded_max_runtime\",job_runtime=$(( ($JOB_TIMESTAMP-$EXISTING_SERVICE_TIMESTAMP)/60000000000 )) $EXISTING_SERVICE_TIMESTAMP" \
      || echo "Service task has exited"

    # Remove the existing service
    sudo docker service rm $JOB_NAME \
    && echo "Removed existing service" \
    || { echo "Unable to remove the existing service" ; return 1 ; }
    
    return 0
}

azmon_existing_service_remove
# If the function exits with a 1, then the service exists but is not removed.
# IF [ $? = 1 ] then notify?

# Create new service and add a new record in the DB (with current JOB_TIMESTAMP)
sudo docker service create \
     --name $JOB_NAME \
     --label timestamp=$JOB_TIMESTAMP \
     --detach \
     --restart-condition none \
     --network="azmon" \
     --mount type=bind,src=/azmon/azurecli,dst=/azmon/azurecli \
     --env JOB_NAME=$JOB_NAME \
     --env JOB_TIMESTAMP=$JOB_TIMESTAMP \
     --secret fqdn \
     --secret subscription_Id \
     --secret app_Id \
     --secret app_Key \
     microsoft/azure-cli \
     $JOB_SCRIPT \
  && curl -s -i -XPOST "http://localhost:8086/write?db=azmon" --data-binary "$JOB_NAME job=0,job_status=\"created\" $JOB_TIMESTAMP" \
  || echo "Unable to create service"