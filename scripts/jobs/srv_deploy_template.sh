#!/bin/bash
SCRIPT_VERSION=0.5

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################## Task: Auth #################################
azs_task_start auth

# Login to Azure Stack cloud 
# Provide argument "adminmanagement" for authenticating to admin endpoint
# Provide argument "management" for authenticating to tenant endpoint
azs_login management

azs_task_end auth
################################# Task: Create ################################
azs_task_start create

# Get location from FQDN
FQDN=$(cat /run/secrets/fqdn)
LOCATION=${FQDN%%.*}

# Create the resource group if it doesn't already exist
az group create \
  --location $LOCATION \
  --name $(cat /run/secrets/uniqueString)

az group deployment create \
  --resource-group $(cat /run/secrets/uniqueString) \
  --name bootstrap \
  --template-uri "$(cat /run/secrets/baseUrl)"/linked/readTemplate.json
  --parameters uniqueString=$(cat /run/secrets/uniqueString)

azs_task_end create
############################### Job: Complete #################################
azs_job_end