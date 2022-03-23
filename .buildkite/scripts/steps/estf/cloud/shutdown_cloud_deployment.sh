#!/usr/bin/env bash

set -euo pipefail

echo "Shutdown cloud deployment"

if [ -z "$EC_API_KEY" ]; then
  echo "ec api key is empty"
fi

if [ -z "$ESTF_ELASTICSEARCH_URL" ]; then
  echo "es url is empty"
fi

#VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
#VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
#VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
#retry 5 30 vault login -no-print "$VAULT_TOKEN"

#EC_API_KEY="$(vault kv get --field apiKey secret/stack-testing/estf-cloud)"
#export EC_API_KEY

buildkite-agent meta-data exists "estf-deployment-id"

ESTF_DEPLOYMENT_ID=$(buildkite-agent meta-data get "estf-deployment-id")

ecctl deployment shutdown --force $ESTF_DEPLOYMENT_ID

#retry 2 15 vault delete "secret/stack-testing/$ESTF_DEPLOYMENT_ID"