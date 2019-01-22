#!/bin/bash
SCRIPT_VERSION=0.1

echo "############ Date     : $(date)"
echo "############ Job name : $JOB_NAME"
echo "############ Version  : $SCRIPT_VERSION"

echo "## Task: source functions"

# Source functions.sh
source /azmon/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

# Add script version job
azmon_log_field N script_version $SCRIPT_VERSION

echo "## Task: auth"

# Login to cloud ("adminmanagement" for admin endpoint, "management" for tenant endpoint)
azmon_login management

echo "## Task: read storage"

az resource list \
  && azmon_log_field T status tenant_read_storage \
  || azmon_log_field T status tenant_read_storage fail

# Update log with runtime for job
azmon_log_runtime job
# Update log with completed job 
azmon_log_field N job 100