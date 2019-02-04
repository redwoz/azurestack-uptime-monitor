#!/bin/bash
SCRIPT_VERSION=0.5

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################## Task: Read #################################
azs_task_start read

STORAGE_ACCOUNT_NAME="$(cat /run/secrets/uniqueString)"storage
BLOB_ENDPOINT=".blob.${FQDN}"

ech $(curl https://${STORAGE_ACCOUNT_NAME}${BLOB_ENDPOINT}/test/read.log)

azs_task_end read
############################### Job: Complete #################################
azs_job_end