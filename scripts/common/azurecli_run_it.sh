### On the host ###

JOB_NAME=azurecli_debug
JOB_TIMESTAMP=$(date --utc +%s)

# run contain from the host
sudo docker service create \
     --name $JOB_NAME \
     --label timestamp=$JOB_TIMESTAMP \
     --detach \
     -t \
     --restart-condition none \
     --network="azmon" \
     --mount type=bind,src=/azmon/common,dst=/azmon/common \
     --mount type=bind,src=/azmon/jobs,dst=/azmon/jobs \
     --env JOB_NAME=$JOB_NAME \
     --env JOB_TIMESTAMP=$JOB_TIMESTAMP \
     --secret fqdn \
     --secret subscription_Id \
     --secret app_Id \
     --secret app_Key \
     --secret tenant_Id \
     --secret grafana_Admin \
     microsoft/azure-cli \
     /bin/bash 

# Exec to the VM
sudo docker exec -it $(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}") /bin/bash

### In the container ###

# Source the functions
source /azmon/common/functions.sh

# Login (management or adminmanagement)
azmon_login adminmanagement