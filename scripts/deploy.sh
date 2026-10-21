#!/usr/bin/env bash
# Put one model version on the online endpoint and mark it as champion. Also used for rollback.
# Usage: scripts/deploy.sh <model_version>   (needs AML_WORKSPACE, AZURE_RESOURCE_GROUP, ENDPOINT_NAME)
set -euo pipefail
VERSION=$1
AML="--workspace-name $AML_WORKSPACE --resource-group $AZURE_RESOURCE_GROUP"
MODEL=taxi-fare-model

az ml model show $AML -n $MODEL -v "$VERSION" --query name -o tsv >/dev/null # fails if missing

if ! az ml online-endpoint show $AML -n "$ENDPOINT_NAME" >/dev/null 2>&1; then
  echo "creating endpoint $ENDPOINT_NAME"
  az ml online-endpoint create $AML -n "$ENDPOINT_NAME" -f aml/endpoints/endpoint.yml
fi

# One deployment "champion", updated in place: a second deployment would not fit the quota.
if az ml online-deployment show $AML -e "$ENDPOINT_NAME" -n champion >/dev/null 2>&1; then
  echo "updating deployment champion -> $MODEL:$VERSION"
  az ml online-deployment update $AML -e "$ENDPOINT_NAME" -f aml/endpoints/deployment.yml \
    --set model="azureml:$MODEL:$VERSION"
else
  echo "creating deployment champion -> $MODEL:$VERSION (first time ~10-15 min)"
  az ml online-deployment create $AML -e "$ENDPOINT_NAME" -f aml/endpoints/deployment.yml \
    --set model="azureml:$MODEL:$VERSION" endpoint_name="$ENDPOINT_NAME" --all-traffic
fi

# champion tag: only on the version the endpoint really serves.
for OLD in $(az ml model list $AML -n $MODEL --query "[?tags.champion=='true'].version" -o tsv); do
  [ "$OLD" = "$VERSION" ] || az ml model update $AML -n $MODEL -v "$OLD" --remove tags.champion >/dev/null
done
az ml model update $AML -n $MODEL -v "$VERSION" --set tags.champion=true >/dev/null
echo "$MODEL v$VERSION is champion on $ENDPOINT_NAME"
