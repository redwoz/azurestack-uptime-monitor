#!/bin/bash
SCRIPT_VERSION=0.1

echo "############ Date     : $(date)"
echo "############ Job name : $JOB_NAME"
echo "############ Version  : $SCRIPT_VERSION"

echo "## Task: source functions"

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

# Add script version job
azs_log_field N script_version $SCRIPT_VERSION

echo "## Task: auth"

# Login to cloud ("adminmanagement" for admin endpoint, "management" for tenant endpoint)
azs_login management

echo "## Task: read storage"

az resource list \
  && azs_log_field T status tenant_read_storage \
  || azs_log_field T status tenant_read_storage fail

# Update log with runtime for job
azs_log_runtime job
# Update log with completed job 
azs_log_field N job 100