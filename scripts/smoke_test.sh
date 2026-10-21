#!/usr/bin/env bash
# Send 3 trips to the endpoint and check the answers make sense.
# Usage: scripts/smoke_test.sh <expected_version>   (needs AML_WORKSPACE, AZURE_RESOURCE_GROUP, ENDPOINT_NAME)
set -euo pipefail
EXPECTED=$1
AML="--workspace-name $AML_WORKSPACE --resource-group $AZURE_RESOURCE_GROUP"

SERVED=$(az ml online-deployment show $AML -e "$ENDPOINT_NAME" -n champion --query model -o tsv)
echo "served model: $SERVED"
[[ "$SERVED" == *"/versions/$EXPECTED" || "$SERVED" == *":$EXPECTED" ]] ||
  { echo "::error::expected version $EXPECTED, endpoint serves $SERVED"; exit 1; }

PRED=$(az ml online-endpoint invoke $AML -n "$ENDPOINT_NAME" \
  --request-file aml/endpoints/sample-request.json -o tsv)
echo "predictions: $PRED"
python3 scripts/check_predictions.py "$PRED"
