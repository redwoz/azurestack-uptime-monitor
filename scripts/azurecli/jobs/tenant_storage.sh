#!/bin/bash
SCRIPT_VERSION=0.1

echo "############ Date     : $(date)"
echo "############ Job name : $JOB_NAME"
echo "############ Version  : $SCRIPT_VERSION"

# Add script version job
azmon_log_field version $SCRIPT_VERSION

echo "## Task: source functions"

# Source functions.sh
source /azmon/azurecli/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

echo "## Task: auth"

# Login to cloud ("adminmanagement" for admin endpoint, "management" for tenant endpoint)
azmon_login management

echo "## Task: read storage"

az resource list \
  && azmon_log_status tenant_read_storage pass \
  || azmon_log_status tenant_read_storage fail

# Update log with runtime for job
azmon_log_runtime job
# Update log with completed job 
azmon_log_field job 1