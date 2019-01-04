#!/bin/bash

echo "================== pnu.sh - auth - $(date)"

# Source functions.sh
source /azmon/azurecli/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

# Login to cloud ("adminmanagement" for admin endpoint, "management" for tenant endpoint)
azmon_login adminmanagement

echo "================== pnu.sh - logic - $(date)"

UPDATE_LOCATIONS=$(az resource list --resource-type "Microsoft.Update.Admin/updateLocations") \
  && azmon_log_status pnu_update_locations pass \
  || azmon_log_status pnu_update_locations fail

STATUS=$(az resource show \
  --name $(echo $UPDATE_LOCATIONS | jq -r ".[0].location") \
  --resource-group $(echo $UPDATE_LOCATIONS | jq -r ".[0].resourceGroup") \
  --resource-type "Microsoft.Update.Admin/updateLocations") \
  && azmon_log_status pnu_update_status pass \
  || azmon_log_status pnu_update_status fail

# Job completed, write job runtime
azmon_log_job job 1