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

#######################
################## EDIT
#######################
#
# Get all update locations
# az resource list --resource-type "Microsoft.Update.Admin/updateLocations" | jq -r "."
#
# Get the ID of the first update location
# UPDATE_LOCATION_RESOURCEID=$(az resource list --resource-type "Microsoft.Update.Admin/updateLocations" | jq -r ".[0].id")
#
# az resource show --ids $UPDATE_LOCATION_RESOURCEID
#
# 
# TOKEN=$(az account get-access-token | jq -r ".accessToken")
# curl -sX GET -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" https://adminmanagement.REGION.FQDN/subscriptions/9f2244d0-4ebc-4f7e-ade7-48d0f53c7b0b/resourcegroups/system.3173r04a/providers/Microsoft.Update.Admin/updateLocations/3173r04a/updates?api-version=2016-05-01 | jq -r ".value[0]"
#
#######################
################## EDIT
#######################

UPDATE_LOCATION_STATUS=$(az resource show \
  --name $(echo $UPDATE_LOCATIONS_LIST | jq -r ".[0].location") \
  --resource-group $(echo $UPDATE_LOCATIONS_LIST | jq -r ".[0].resourceGroup") \
  --resource-type "Microsoft.Update.Admin/updateLocations") \
  && azmon_log_field T status admin_pnu_update_location_status \
  || azmon_log_field T status admin_pnu_update_location_status fail

CURRENT_UPDATE_VERSION=$(echo $UPDATE_LOCATION_STATUS | jq -r ".properties.currentVersion") \
  && azmon_log_field N status admin_pnu_current_version \
  || azmon_log_field N status admin_pnu_current_version fail

azmon_log_field T pnu_current_version ${CURRENT_VERSION}

CURRENT_UPDATE_STATE=$(echo $UPDATE_LOCATION_STATUS | jq -r ".properties.state") \
  && azmon_log_field T status admin_pnu_current_state \
  || azmon_log_field T status admin_pnu_current_version fail

azmon_log_field T pnu_current_update_state_label ${CURRENT_STATE}

echo "## Task: annotations"
# Get the latest PnU status from the influxDB (query on annotations measure)

RANGE_LAST=$(curl -s -G 'http://influxdb:8086/query?db=azmon' --data-urlencode 'q=SELECT * FROM "range_pnu" GROUP BY * ORDER BY DESC LIMIT 1')

echo "############################### RANGE_LAST"
echo $RANGE_LAST

RANGE_NEW_BODY=$(cat << END
{
  "time":$(($(date --utc +%s)*1000)),
  "timeEnd":$(($(date --utc +%s)*1000)),
  "isRegion":true,
  "tags":["$CURRENT_UPDATE_STATE"],
  "text":"Current update version is $CURRENT_UPDATE_VERSION"
}
END
)

# If no results are returned
if [[ $(echo "$RANGE_LAST" | jq -r ".results[].series") == null ]]; then

  # Write new annotation to Grafana (no need to update existing one since it doesn't exist yet)
  # Capture the result in a variable for the annotation Id
  RANGE_NEW_ID=$(curl -sX POST -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) -d "$RANGE_NEW_BODY" http://grafana:3000/api/annotations | jq -r ".id")
  # RANGE_NEW_REGION_ID=$(curl -sX GET -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_NEW_ID) | .regionId")

  # Write new annotation to the Influx (no need to update existing one, since it doesn't exist yet)
  curl -s -i -XPOST "http:/influxdb:8086/write?db=azmon&precision=s" --data-binary "range_pnu range_id=\"$RANGE_NEW_ID\",time_start=$(($(date --utc +%s)*1000)),state=\"$CURRENT_UPDATE_STATE\",tags=\"$CURRENT_UPDATE_STATE\",text=\"Current update version is $CURRENT_UPDATE_VERSION\"" | grep HTTP

else 

  echo "############################### results are returned" 

  # Query for last entry in range_pnu measure in Influx
  RANGE_LAST_ENTRY=$(curl -s -G 'http://influxdb:8086/query?db=azmon&epoch=s' --data-urlencode 'q=SELECT range_id, time_start, state, tags, text FROM "range_pnu" GROUP BY * ORDER BY DESC LIMIT 1' | jq -r ".results[].series[].values[]")
  RANGE_LAST_TIMESTAMP=$(echo $RANGE_LAST_ENTRY | jq -r ".[0]")
  RANGE_LAST_ID=$(echo $RANGE_LAST_ENTRY | jq -r ".[1]")
  RANGE_LAST_START=$(echo $RANGE_LAST_ENTRY | jq -r ".[2]")
  RANGE_LAST_STATE=$(echo $RANGE_LAST_ENTRY | jq -r ".[3]")
  RANGE_LAST_TAGS=$(echo $RANGE_LAST_ENTRY | jq -r ".[4]")
  RANGE_LAST_TEXT=$(echo $RANGE_LAST_ENTRY | jq -r ".[5]")


  RANGE_UPDATE_BODY=$(cat << END
{
  "time":$RANGE_LAST_START,
  "isRegion":true,
  "timeEnd":$(($(date --utc +%s)*1000)),
  "text":"$RANGE_LAST_TEXT",
  "tags":["$RANGE_LAST_TAGS"]
}
END
)


  RANGE_PLUSONE=$(( $RANGE_LAST_ID+1 ))
  ###################### GET Existing value
  echo "################## existing grafana value before update"
  curl -s -XGET -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_LAST_ID)"
  curl -s -XGET -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_PLUSONE)"

  # Update the existing annotation endTime in the Grafana db
  curl -sX PUT -H 'Content-Type: application/json' -H 'Accept: application/json' -u admin:$(cat /run/secrets/grafana_Admin) -d "$RANGE_UPDATE_BODY" http://grafana:3000/api/annotations/$RANGE_LAST_ID

  ###################### GET Existing value
  echo "################## existing grafana value before update"
  curl -s -XGET -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_LAST_ID)"
  curl -s -XGET -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_PLUSONE)"

  # Updating the influxDB entry with the new endtime
  curl -s -i -XPOST "http:/influxdb:8086/write?db=azmon&precision=s" --data-binary "range_pnu time_end=$(($(date --utc +%s)*1000)) $RANGE_LAST_TIMESTAMP" | grep HTTP
  
  if [ "$CURRENT_UPDATE_STATE" != "$RANGE_LAST_STATE" ]; then
    
    # Create new annotation
    RANGE_NEW_ID=$(curl -sX POST -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) -d "$RANGE_NEW_BODY" http://grafana:3000/api/annotations | jq -r ".id")
    #RANGE_NEW_REGION_ID=$(curl -sX GET -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_NEW_ID) | .regionId")
    curl -s -i -XPOST "http:/influxdb:8086/write?db=azmon&precision=s" --data-binary "range_pnu range_id=\"$RANGE_NEW_ID\",time_start=$(($(date --utc +%s)*1000)),state=\"$CURRENT_UPDATE_STATE\",tags=\"$CURRENT_UPDATE_STATE\",text=\"Current update version is $CURRENT_UPDATE_VERSION\"" | grep HTTP

  fi  
fi

# https://docs.microsoft.com/en-us/rest/api/azurestack/updatelocations/list#regionupdatestate
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