#!/bin/bash

# Source functions.sh
source /azs/cli/shared/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################# Task: Probe #################################
azs_task_start probe

openssl s_client \
      -connect adminportal.$(cat /run/secrets/cli | jq -r '.fqdn'):443 \
      -servername adminportal.$(cat /run/secrets/cli | jq -r '.fqdn') \
  && azs_log_field T status admin_portal_openssl_connect \
  || azs_log_field T status admin_portal_openssl_connect fail

azs_task_end probe
############################### Job: Complete #################################
azs_job_end