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
azmon_login adminmanagement

echo "## Task: Get Locations"

UPDATE_LOCATIONS_LIST=$(az resource list --resource-type "Microsoft.Update.Admin/updateLocations") \
  && azmon_log_field T status admin_pnu_update_locations_list \
  || azmon_log_field T status admin_pnu_update_locations_list fail

UPDATE_LOCATION_STATUS=$(az resource show \
  --name $(echo $UPDATE_LOCATIONS_LIST | jq -r ".[0].location") \
  --resource-group $(echo $UPDATE_LOCATIONS_LIST | jq -r ".[0].resourceGroup") \
  --resource-type "Microsoft.Update.Admin/updateLocations") \
  && azmon_log_field T status admin_pnu_update_location_status \
  || azmon_log_field T status admin_pnu_update_location_status fail

CURRENT_UPDATE_VERSION=$(echo $UPDATE_LOCATION_STATUS | jq -r ".properties.currentVersion") \
  && azmon_log_field T status admin_pnu_current_version \
  || azmon_log_field T status admin_pnu_current_version fail

azmon_log_field T pnu_current_version ${CURRENT_VERSION}

CURRENT_UPDATE_STATE=$(echo $UPDATE_LOCATION_STATUS | jq -r ".properties.state") \
  && azmon_log_field T status admin_pnu_current_state \
  || azmon_log_field T status admin_pnu_current_version fail

azmon_log_field T pnu_current_update_state_label ${CURRENT_STATE}

# 10 = UpdateInProgress 
# 4  = AppliedUpdateAvailableSuccessfully
# 2  = AppliedSuccessfully 
# 0  = No entry in database (e.g. when azmon VM is down)
# -2 = Unknown
# -4 = Failed

case "$CURRENT_UPDATE_STATE" in
  "UpdateInProgress")
    azmon_log_field N pnu_current_update_state 10
    ;;
  "AppliedUpdateAvailableSuccessfully")
    azmon_log_field N pnu_current_update_state 4
    ;;
  "AppliedSuccessfully")
    azmon_log_field N pnu_current_update_state 2
    ;;
  "Unknown")
    azmon_log_field N pnu_current_update_state -2
    ;;
  "Failed")
    azmon_log_field N pnu_current_update_state -4
    ;;
esac

# Update log with runtime for job
azmon_log_runtime job
# Update log with completed job 
azmon_log_field N job 1