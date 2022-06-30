#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to delete cloud deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/common/util.sh

echo "--- Shutdown ESS Deployment"

KEYS=$(buildkite-agent meta-data keys)
DEPLOYMENT_KEY="estf-deployment-id-$ESTF_META_ID"
if [[ "$KEYS" == *"$DEPLOYMENT_KEY"* ]]; then
  ESTF_DEPLOYMENT_ID=$(buildkite-agent meta-data get "estf-deployment-id-$ESTF_META_ID")
else
  DEPLOYMENT_OUTPUT_FILE=$(buildkite-agent meta-data get "estf-deployment-output-$ESTF_META_ID")
  if [ $(cat $DEPLOYMENT_OUTPUT_FILE | jq empty > /dev/null 2>&1; echo $?) -eq 0 ]; then
    ESTF_DEPLOYMENT_ID=$(jq -sr '.[0].id' "$DEPLOYMENT_OUTPUT_FILE")
    cat << EOF | buildkite-agent annotate --style 'error' --context 'ess_error_deployment' --append
      $ESTF_META_ID deployment error: $ESTF_DEPLOYMENT_ID<br>
EOF
  else
    cat << EOF | buildkite-agent annotate --style 'error' --context 'ess_error_deployment' --append
      $ESTF_META_ID deployment error: $(cat $DEPLOYMENT_OUTPUT_FILE)<br>
EOF
  echo_error_exit "Deployment error"
  fi
fi

VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
retry 5 30 vault login -no-print "$VAULT_TOKEN"

EC_API_KEY="$(vault kv get --field apiKey secret/stack-testing/estf-cloud)"
export EC_API_KEY

ecctl deployment shutdown --force $ESTF_DEPLOYMENT_ID
