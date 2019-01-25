#!/bin/bash
SCRIPT_VERSION=0.2

# Source functions.sh
source /azs/common/functions.sh \
  && echo "Sourced functions.sh" \
  || { echo "Failed to source functions.sh" ; exit ; }

################################# Task: Export ################################
azs_task_start export

CSV_YEAR=${1:-$(date --utc +%y)}
CSV_WEEK=${2:-$(date --utc -d 'last week' +%U)}
CSV_FILE_NAME=y${CSV_YEAR}w${CSV_WEEK}

# Date format to export
CSV_DATE_FORMAT="+%Y-%m-%d %H:%M:%S"

# First week of the year
CSV_WEEK_NUM_OF_JAN_1=$(date -d ${CSV_YEAR}-01-01 +%U)
CSV_WEEK_DAY_OF_JAN_1=$(date -d ${CSV_YEAR}-01-01 +%u)

# Start of the first week of the year
if ((WEEK_DAY_OF_JAN_1)); then
    CSV_FIRST_SUNDAY=${CSV_YEAR}-01-01
else
    CSV_FIRST_SUNDAY=${CSV_YEAR}-01-$((01 + (7 - CSV_WEEK_DAY_OF_JAN_1) ))
fi

# Get start and end date for the year and weeknumber
CSV_DATE_START=$(date -d "$CSV_FIRST_SUNDAY +$((CSV_WEEK - 1)) week" "$CSV_DATE_FORMAT")
CSV_DATE_END=$(date -d "$CSV_FIRST_SUNDAY +$((CSV_WEEK - 1)) week + 7 day - 1 sec" "$CSV_DATE_FORMAT")

# Export data to file
sudo curl -G 'http://localhost:8086/query?db=azs' \
   --data-urlencode "q=SELECT * FROM /.*/ where time >= '$CSV_DATE_START' and time <= '$CSV_DATE_END'" \
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
azs_task_start upload


azs_task_end upload
############################### Job: Complete #################################
azs_job_end

