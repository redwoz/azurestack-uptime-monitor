#!/bin/bash
SCRIPT_VERSION=0.6

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################## Task: Read #################################
azs_task_start read

STORAGE_ACCOUNT_NAME="$(cat /run/secrets/uniqueString)"storage
BLOB_ENDPOINT=.blob."$(cat /run/secrets/fqdn)"

FILE_CONTENT=$(curl https://${STORAGE_ACCOUNT_NAME}${BLOB_ENDPOINT}/test/read.log) \
  && azs_log_field T status tenant_storage_read_file \
  || azs_log_field T status tenant_storage_read_file fail

[ "$FILE_CONTENT" = "$(cat /run/secrets/uniqueString)" ] \
  && azs_log_field T status tenant_storage_compare_content \
  || azs_log_field T status tenant_storage_compare_content fail

azs_task_end read
############################### Job: Complete #################################
azs_job_end