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
if [[ -z $(echo "$RANGE_LAST" | jq -r ".results[].series") ]]; then
  # Write new annotation to Grafana (no need to update existing one since it doesn't exist yet)
  # Capture the result in a variable for the annotation Id
  RANGE_NEW_ID=$(curl -sX POST -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) -d "$RANGE_NEW_BODY" http://grafana:3000/api/annotations | jq -r ".id")
  RANGE_NEW_REGION_ID=$(curl -sX GET -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_NEW_ID) | .regionId")

  # Write new annotation to the Influx (no need to update existing one, since it doesn't exist yet)
  curl -s -i -XPOST "http:/influxdb:8086/write?db=azmon&precision=s" --data-binary "range_pnu state=\"$CURRENT_UPDATE_STATE\",range_id=\"$RANGE_NEW_ID\",range_region_id=\"$RANGE_NEW_REGION_ID\",start_time=$(($(date --utc +%s)*1000000000))" | grep HTTP

else 
  # Query for last entry in range_pnu measure in Inlfux
  RANGE_LAST_TIMESTAMP=$(curl -s -G 'http://influxdb:8086/query?db=azmon&epoch=s' --data-urlencode 'q=SELECT * FROM "range_pnu" GROUP BY * ORDER BY DESC LIMIT 1' | jq -r ".results[].series[].values[][0]")
  RANGE_LAST_STATE=$(curl -s -G 'http://influxdb:8086/query?db=azmon' --data-urlencode 'q=SELECT state FROM "range_pnu" GROUP BY * ORDER BY DESC LIMIT 1' | jq -r ".results[].series[].values[][1]")
  RANGE_LAST_ID=$(curl -s -G 'http://influxdb:8086/query?db=azmon' --data-urlencode 'q=SELECT range_id FROM "range_pnu" GROUP BY * ORDER BY DESC LIMIT 1' | jq -r ".results[].series[].values[][1]")
  RANGE_LAST_REGION_ID=$(curl -s -G 'http://influxdb:8086/query?db=azmon' --data-urlencode 'q=SELECT range_region_id FROM "range_pnu" GROUP BY * ORDER BY DESC LIMIT 1' | jq -r ".results[].series[].values[][1]")

  # Query for last entry in Grafana
  GRAFANA_RANGE_LAST_TIMESTAMP=$(curl -s -XGET -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_LAST_ID) | .time")
  GRAFANA_RANGE_LAST_TAGS=$(curl -s -XGET -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_LAST_ID) | .tags")
  GRAFANA_RANGE_LAST_TEXT=$(curl -s -XGET -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_LAST_ID) | .text")
  RANGE_UPDATE_BODY=$(cat << END
  {
    "time":$GRAFANA_RANGE_LAST_TIMESTAMP,
    "timeEnd":$(($(date --utc +%s)*1000)),
    "isRegion":true,
    "tags":$GRAFANA_RANGE_LAST_TAGS,
    "text":"$GRAFANA_RANGE_LAST_TEXT"
  }
END
)

  # Deleting the regionid and creating a new one in Grafana (a PUT on the id with the start time has a bug resulting in the endId with time set to 0)
  curl -sX DELETE -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations/region/$RANGE_LAST_REGION_ID
  RANGE_NEW_ID=$(curl -sX POST -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) -d "$RANGE_UPDATE_BODY" http://grafana:3000/api/annotations | jq -r ".id")
  RANGE_NEW_REGION_ID=$(curl -sX GET -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_NEW_ID) | .regionId")

  # Updating the influxDB entry with the new regionID
  curl -s -i -XPOST "http:/influxdb:8086/write?db=azmon&precision=s" --data-binary "range_pnu range_id=\"$RANGE_NEW_ID\",range_region_id=\"$RANGE_NEW_REGION_ID\",endTime=\"$(($(date --utc +%s)*1000000000))\" $RANGE_LAST_TIMESTAMP" | grep HTTP
  
  
  if [ "$CURRENT_UPDATE_STATE" != "$RANGE_LAST_STATE" ]; then
    
    # Create new annotation
    RANGE_NEW_ID=$(curl -sX POST -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) -d "$RANGE_NEW_BODY" http://grafana:3000/api/annotations | jq -r ".id")
    RANGE_NEW_REGION_ID=$(curl -sX GET -H "Accept: application/json" -H "Content-Type: application/json" -u admin:$(cat /run/secrets/grafana_Admin) http://grafana:3000/api/annotations | jq -r ".[] | select(.id==$RANGE_NEW_ID) | .regionId")
    curl -s -i -XPOST "http:/influxdb:8086/write?db=azmon&precision=s" --data-binary "range_pnu state=\"$CURRENT_UPDATE_STATE\",range_id=\"$RANGE_NEW_ID\",range_region_id=\"$RANGE_NEW_REGION_ID\",start_time=$(($(date --utc +%s)*1000000000))" | grep HTTP

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