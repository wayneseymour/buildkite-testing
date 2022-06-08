#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to delete cloud deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/common/util.sh

echo "--- Shutdown ESS Deployment"

buildkite-agent meta-data exists "estf-deployment-id-$ESTF_META_ID"

VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
retry 5 30 vault login -no-print "$VAULT_TOKEN"

EC_API_KEY="$(vault kv get --field apiKey secret/stack-testing/estf-cloud)"
export EC_API_KEY

ESTF_DEPLOYMENT_ID=$(buildkite-agent meta-data get "estf-deployment-id-$ESTF_META_ID")

ecctl deployment shutdown --force $ESTF_DEPLOYMENT_ID
