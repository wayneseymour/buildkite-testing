#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to delete instance using terraform
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/common/util.sh

echo "--- Delete TF Instance"

VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
retry 5 30 vault login -no-print "$VAULT_TOKEN"

TF_VAR_credentials="$(vault kv get --field policy secret/stack-testing/estf-gcp)"
export TF_VAR_credentials

export TF_VAR_os_image="ubuntu-os-pro-cloud/ubuntu-pro-2204-lts"

export TF_WORKSPACE="$(pwd)/.buildkite/scripts/steps/estf/terraform/gcp"

echo "--- TF destroy"
docker run --rm \
           -it \
           --name terraform \
           -v $TF_WORKSPACE:/workspace \
           -w /workspace \
           -e "TF_VAR_credentials=$TF_VAR_credentials" \
           -e "TF_VAR_os_image=$TF_VAR_os_image" \
          hashicorp/terraform:latest destroy -auto-approve
