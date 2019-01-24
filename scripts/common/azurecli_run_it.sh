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
     --network azs \
     --mount type=bind,src=/azs/common,dst=/azs/common \
     --mount type=bind,src=/azs/jobs,dst=/azs/jobs \
     --env JOB_NAME=$JOB_NAME \
     --env JOB_TIMESTAMP=$JOB_TIMESTAMP \
     --secret fqdn \
     --secret subscriptionId \
     --secret appId \
     --secret appKey \
     --secret tenantId \
     --secret grafanaAdmin \
     --secret uniqueString \
     microsoft/azure-cli \
     /bin/bash 

# Exec to the VM
sudo docker exec -it $(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}") /bin/bash

### In the container ###

# Source the functions
source /azs/common/functions.sh

# Login (management or adminmanagement)
azs_login adminmanagement