#!/usr/bin/env bash
# Run the training pipeline in one workspace and wait for it.
# Prints the new model version to $GITHUB_OUTPUT (empty = nothing better than the champion).
# Usage: scripts/train.sh <max_rows> <build_id>     (needs AML_WORKSPACE, AZURE_RESOURCE_GROUP)
set -euo pipefail
MAX_ROWS=$1
BUILD_ID=$2
AML="--workspace-name $AML_WORKSPACE --resource-group $AZURE_RESOURCE_GROUP"

JOB=$(az ml job create $AML -f aml/pipelines/train.yml \
  --set inputs.max_rows="$MAX_ROWS" inputs.build_id="$BUILD_ID" \
  --query name -o tsv)
echo "pipeline job: $JOB"
echo "studio: $(az ml job show $AML -n "$JOB" --query services.Studio.endpoint -o tsv)"

az ml job stream $AML -n "$JOB" || true
STATUS=$(az ml job show $AML -n "$JOB" --query status -o tsv)
echo "status: $STATUS"
[ "$STATUS" = "Completed" ] || { echo "::error::pipeline $JOB finished with $STATUS"; exit 1; }

VERSION=$(az ml model list $AML -n taxi-fare-model \
  --query "[?tags.build_id=='$BUILD_ID'].version | [0]" -o tsv 2>/dev/null || true)
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
if [ -n "$VERSION" ]; then
  TAGS=$(az ml model show $AML -n taxi-fare-model -v "$VERSION" --query tags -o json)
  echo "new model version: $VERSION $TAGS"
  { echo "### $AML_WORKSPACE: new model taxi-fare-model v$VERSION"; echo '```json'; echo "$TAGS"; echo '```'; } >> "$SUMMARY"
else
  echo "no new version registered (not better than the champion)"
  echo "### $AML_WORKSPACE: no new model (not better than the champion)" >> "$SUMMARY"
fi
echo "model_version=$VERSION" >> "${GITHUB_OUTPUT:-/dev/null}"
