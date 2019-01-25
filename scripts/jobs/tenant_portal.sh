#!/bin/bash
SCRIPT_VERSION=0.2

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################# Task: Probe #################################
azs_task_start probe

openssl s_client \
      -connect portal.$(cat /run/secrets/fqdn):443 \
      -servername portal.$(cat /run/secrets/fqdn) \
  && azs_log_field T status admin_portal_openssl_connect \
  || azs_log_field T status admin_portal_openssl_connect fail

azs_task_end probe
############################### Job: Complete #################################
azs_job_end