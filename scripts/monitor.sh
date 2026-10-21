#!/usr/bin/env bash
# Run the monitoring pipeline (champion quality + drift) and print the report.
# Usage: scripts/monitor.sh <max_rows>   (needs AML_WORKSPACE, AZURE_RESOURCE_GROUP)
set -euo pipefail
MAX_ROWS=$1
AML="--workspace-name $AML_WORKSPACE --resource-group $AZURE_RESOURCE_GROUP"

JOB=$(az ml job create $AML -f aml/pipelines/monitor.yml --set inputs.max_rows="$MAX_ROWS" \
  --query name -o tsv)
echo "monitoring job: $JOB"
az ml job stream $AML -n "$JOB" || true
STATUS=$(az ml job show $AML -n "$JOB" --query status -o tsv)
[ "$STATUS" = "Completed" ] || { echo "::error::monitoring $JOB finished with $STATUS"; exit 1; }

mkdir -p monitor_out
az ml job download $AML -n "$JOB" --output-name report --download-path monitor_out >/dev/null
echo '```json'
cat monitor_out/named-outputs/report/report.json
echo '```'
