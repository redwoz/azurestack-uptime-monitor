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
azmon_log_field version $SCRIPT_VERSION

echo "## Task: connect"

openssl s_client -connect adminportal.$(cat /run/secrets/fqdn):443 -servername adminportal.$(cat /run/secrets/fqdn) \
  && azmon_log_status portaladmin_openssl_connect pass \
  || azmon_log_status portaladmin_openssl_connect fail

# Update log with runtime for job
azmon_log_runtime job
# Update log with completed job 
azmon_log_field job 1