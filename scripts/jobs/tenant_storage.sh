#!/bin/bash
SCRIPT_VERSION=0.3

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
################################## Task: Read #################################
azs_task_start read

RESOURCES=$(az resource list) \
  && azs_log_field T status tenant_storage_read \
  || azs_log_field T status tenant_storage_read fail

azs_task_end read
################################# Task: Create ################################
azs_task_start create

RESOURCES=$(az resource list) \
  && azs_log_field T status tenant_storage_create \
  || azs_log_field T status tenant_storage_create fail

azs_task_end create
################################# Task: Update ################################
azs_task_start update

RESOURCES=$(az resource list) \
  && azs_log_field T status tenant_storage_update \
  || azs_log_field T status tenant_storage_update fail

azs_task_end update
################################# Task: Delete ################################
azs_task_start delete

RESOURCES=$(az resource list) \
  && azs_log_field T status tenant_storage_delete \
  || azs_log_field T status tenant_storage_delete fail

azs_task_end delete
############################### Job: Complete #################################
azs_job_end