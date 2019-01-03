#!/bin/bash

echo "$(date)" pnu
########################
echo "================== pnu.sh - auth"

# Source auth.sh
source /azmon/azurecli/common/auth.sh \
  && echo "Sourced auth.sh" \
  || { echo "Failed to source auth.sh" ; exit ; }

# Login to cloud ("adminmanagement" for admin endpoint, "management" for tenant endpoint)
azmon_login adminmanagement

########################
echo "================== pnu.sh - logic"

UPDATE_LOCATIONS=$(az resource list --resource-type "Microsoft.Update.Admin/updateLocations") \
    && curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME job_status=\"pass_update_locations\" $JOB_TIMESTAMP" \
    || { curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME job_status=\"fail_update_locations\" $JOB_TIMESTAMP" ; exit ; }

STATUS=$(az resource show \
    --name $(echo $UPDATE_LOCATIONS | jq -r ".[0].location") \
    --resource-group $(echo $UPDATE_LOCATIONS | jq -r ".[0].resourceGroup") \
    --resource-type "Microsoft.Update.Admin/updateLocations") \
          && curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME job_status=\"pass_update_status\" $JOB_TIMESTAMP" \
          || { curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME job_status=\"fail_update_status\" $JOB_TIMESTAMP" ; exit ; }

# Job completed, write job runtime
CURRENT_TIMESTAMP=$(date --utc +%s%N)
curl -s -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME job=1,job_status=\"pass\",job_runtime=$(( ($JOB_TIMESTAMP-$CURRENT_TIMESTAMP)/60000000000 )) $JOB_TIMESTAMP"