#!/bin/bash

function azmon_login
{
  # Write entry in DB indicating auth is starting
  curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth=0 $JOB_TIMESTAMP"

  # Set REQUESTS_CA_BUNDLE variable with AzureStack root CA
  export REQUESTS_CA_BUNDLE=/azmon/azurecli/common/Certificates.pem \
    && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=pass_ca_bundle $JOB_TIMESTAMP" \
    || { curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=fail_ca_bundle $JOB_TIMESTAMP" ; exit ; }

  ## Register cloud
  az cloud register -n AzureStackCloud --endpoint-resource-manager "https://$1.$(cat /run/secrets/fqdn)" \
    && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=pass_cloud_register $JOB_TIMESTAMP" \
    || { && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=fail_cloud_register $JOB_TIMESTAMP" ; exit ; }

  ## Select cloud
  az cloud set -n AzureStackCloud \
    && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=pass_select_cloud $JOB_TIMESTAMP" \
    || { && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=fail_select_cloud $JOB_TIMESTAMP" ; exit ; }

  ## Api Profile
  az cloud update --profile 2018-03-01-hybrid \
    && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=pass_set_apiprofile $JOB_TIMESTAMP" \
    || { && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=fail_set_apiprofile $JOB_TIMESTAMP" ; exit ; }

  ## Get activeDirectoryResourceId
  TENANT_URI=$(az cloud show -n AzureStackCloud | jq -r ".endpoints.activeDirectoryResourceId") \
    && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=pass_resourceid_uri $JOB_TIMESTAMP" \
    || { && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=fail_resourceid_uri $JOB_TIMESTAMP" ; exit ; }

  ## Get TenantID by selecting value after the last /
  TENANT_ID=${TENANT_URI##*/}
    && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=pass_get_tenantId $JOB_TIMESTAMP" \
    || { && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=fail_get_tenantId $JOB_TIMESTAMP" ; exit ; }

  ## Sign in as SPN
  az login --service-principal --tenant $TENANT_ID -u $(cat /run/secrets/app_Id) -p $(cat /run/secrets/app_Key) \
    && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=pass_login $JOB_TIMESTAMP" \
    || { && curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_status=fail_login $JOB_TIMESTAMP" ; exit ; }
  
  CURRENT_TIMESTAMP=$(date --utc +%s%N)
  curl -i -XPOST "http://influxdb:8086/write?db=azmon" --data-binary "$JOB_NAME auth_runtime=$(( ($JOB_TIMESTAMP-$CURRENT_TIMESTAMP)/60000000000 )) $JOB_TIMESTAMP"
  return 0

}