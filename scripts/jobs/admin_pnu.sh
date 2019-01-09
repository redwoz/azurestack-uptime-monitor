#!/bin/bash
SCRIPT_VERSION=0.1

echo "############ Date     : $(date)"
echo "############ Job name : $JOB_NAME"
echo "############ Version  : $SCRIPT_VERSION"

echo "## Task: source functions"

# Source functions.sh
source /azmon/jobs/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

# Add script version job
azmon_log_field version $SCRIPT_VERSION

echo "## Task: auth"

# Login to cloud ("adminmanagement" for admin endpoint, "management" for tenant endpoint)
azmon_login adminmanagement

echo "## Task: Get Locations"

UPDATE_LOCATIONS=$(az resource list --resource-type "Microsoft.Update.Admin/updateLocations") \
  && azmon_log_status pnu_update_locations pass \
  || azmon_log_status pnu_update_locations fail

STATUS=$(az resource show \
  --name $(echo $UPDATE_LOCATIONS | jq -r ".[0].location") \
  --resource-group $(echo $UPDATE_LOCATIONS | jq -r ".[0].resourceGroup") \
  --resource-type "Microsoft.Update.Admin/updateLocations") \
  && azmon_log_status pnu_update_status pass \
  || azmon_log_status pnu_update_status fail

# Update log with runtime for job
azmon_log_runtime job
# Update log with completed job 
azmon_log_field job 1