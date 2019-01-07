#!/bin/bash
SCRIPT_VERSION=0.1

echo "############ Date     : $(date)"
echo "############ Job name : $JOB_NAME"
echo "############ Version  : $SCRIPT_VERSION"

echo "## Task: source functions"

# Source functions.sh
source /azmon/azurecli/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

# Add script version job
azmon_log_job version $SCRIPT_VERSION

echo "## Task: connect"

openssl s_client -connect portal.$(cat /run/secrets/fqdn):443
  && azmon_log_status portaladmin_openssl_connect pass \
  || azmon_log_status portaladmin_openssl_connect fail

# Job completed, write job runtime
azmon_log_job job 1