### On the host ###

SERVICE_NAME=azurecli_debug

# run contain from the host
sudo docker service create \
     --name $SERVICE_NAME \
     --detach \
     -t \
     --restart-condition none \
     --network="azmon" \
     --mount type=bind,src=/azmon/common,dst=/azmon/common \
     --mount type=bind,src=/azmon/jobs,dst=/azmon/jobs \
     --secret fqdn \
     --secret subscription_Id \
     --secret app_Id \
     --secret app_Key \
     --secret tenant_Id \
     microsoft/azure-cli \
     /bin/bash 

# Exec to the VM
sudo docker exec -it $(sudo docker container ls -a --filter name=$SERVICE_NAME --format "{{.ID}}") /bin/bash

### In the container ###

# Source the functions
source /azmon/common/functions.sh

# Login (management or adminmanagement)
azmon_login adminmanagement