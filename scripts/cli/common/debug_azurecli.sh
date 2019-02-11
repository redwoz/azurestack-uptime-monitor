#!/bin/bash
#SCRIPT_VERSION=0.5

### On the host ###
JOB_NAME=debug_azurecli
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
     --mount type=bind,src=/azs/log,dst=/azs/log \
     --mount type=bind,src=/azs/export,dst=/azs/export \
     --env JOB_NAME=$JOB_NAME \
     --env JOB_TIMESTAMP=$JOB_TIMESTAMP \
     --secret fqdn \
     --secret storageAccount \
     --secret tenantSubscriptionId \
     --secret azureSubscriptionId \
     --secret appId \
     --secret appKey \
     --secret tenantId \
     --secret grafanaAdmin \
     --secret uniqueString \
     --secret baseUrl \
     --secret activationKey \
     microsoft/azure-cli \
     /bin/bash 

# Wait for container to start
Y=15
while [ $Y -ge 1 ]
do
  CONTAINERID=$(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}")
  if [ $CONTAINERID <> 0 ]; then break; fi
  echo "Waiting for container to start. $Y seconds"
  sleep 1s
  Y=$(( $Y - 1 ))
  if [ $Y = 0 ]; then { echo "## Fail: srv_bootstrap_tenant container did not start" ; exit 1 ; }; fi
done

# Exec to the VM
sudo docker exec -it $(sudo docker container ls -a --filter name=$JOB_NAME --format "{{.ID}}") /bin/bash
