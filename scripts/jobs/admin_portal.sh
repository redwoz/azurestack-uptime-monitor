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

echo "## Task: connect"

openssl s_client -connect adminportal.$(cat /run/secrets/fqdn):443 -servername adminportal.$(cat /run/secrets/fqdn) \
  && azs_log_field T status admin_portal_openssl_connect \
  || azs_log_field T status admin_portal_openssl_connect fail

# Update log with runtime for job
azs_log_runtime job
# Update log with completed job 
azs_log_field N job 100