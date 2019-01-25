#!/bin/bash
SCRIPT_VERSION=0.2

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################# Task: Export ################################
azs_task_start export

# Get the current year
CSV_YEAR=$(date --utc +%y)
# Get last week and return two digits
CSV_WEEK=0$(( $(date --utc +%U) - 1 ))
CSV_WEEK="${CSV_WEEK: -2}"
# Set filename
CSV_FILE_NAME=y${CSV_YEAR}w${CSV_WEEK}

# First week of the year
CSV_WEEK_NUM_OF_JAN_1=$(date --utc -d ${CSV_YEAR}-01-01 +%U)
CSV_WEEK_DAY_OF_JAN_1=$(date --utc -d ${CSV_YEAR}-01-01 +%u)

# Start of the first week of the year
if ((WEEK_DAY_OF_JAN_1)); then
    CSV_FIRST_SUNDAY_EPOCH=$(date --utc -d ${CSV_YEAR}-01-01 -D "%y-%m-%d" +%s)
else
    CSV_FIRST_SUNDAY_EPOCH=$(date --utc -d ${CSV_YEAR}-01-$((01 + (7 - CSV_WEEK_DAY_OF_JAN_1) )) -D "%y-%m-%d" +%s)
fi

# One week of seconds is 60s x 60m x 24h x 7d = 604800s
# To get the last week in epoch
# StartTime : Add last weeks number (current week number - 1) multiplied by seconds, to the first day of the year
CSV_DATE_START=$(( CSV_FIRST_SUNDAY_EPOCH + $(( ( CSV_WEEK - 1 ) * 604800 )) ))
# Endtime : Add this weeks number (current week number) multiplied by seconds, minus one second, to the first day of the year
CSV_DATE_END=$(( CSV_FIRST_SUNDAY_EPOCH + $(( ( CSV_WEEK * 604800 ) - 1 )) ))

# Export data to file
curl -G 'http://influxdb:8086/query?db=azs&precision=s' \
   --data-urlencode "q=SELECT * FROM /.*/ where time >= $CSV_DATE_START and time <= $CSV_DATE_END" \
   -H "Accept: application/csv" \
   -o /azs/export/$CSV_FILE_NAME.csv \
 && echo "export completed succesfully" \
 || echo "export failed"

azs_task_end export
################################## Task: Auth #################################
azs_task_start auth

# Login to Azure Stack cloud 
# Provide argument "adminmanagement" for authenticating to admin endpoint
# Provide argument "management" for authenticating to tenant endpoint
azs_login management

azs_task_end auth
################################# Task: Upload ################################
#azs_task_start upload

# Create storage account (if exists? with exisisting data?)
# Create container (if exists? with exisisting data?)
# Get keys from storage account
# For each file in /azs/export > upload to container (if exists? with exisisting data?)

#azs_task_end upload
############################### Job: Complete #################################
azs_job_end

