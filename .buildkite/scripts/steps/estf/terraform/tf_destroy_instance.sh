#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to delete instance using terraform
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/common/util.sh

echo "--- Delete TF Instance"

gcloud config set account "elastic-buildkite-agent@elastic-kibana-ci.iam.gserviceaccount.com"

VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
retry 5 30 vault login -no-print "$VAULT_TOKEN"

TF_VAR_credentials="$(vault kv get --field policy secret/stack-testing/estf-gcp)"
export TF_VAR_credentials

export TF_VAR_os_image="$AIT_IMAGE"

export TF_VAR_machine_type="c2-standard-8"
if [[ ! -z ${AIT_MACHINE_TYPE:-} ]]; then
  export TF_VAR_machine_type="$AIT_MACHINE_TYPE"
fi

export TF_WORKSPACE="$(pwd)/.buildkite/scripts/steps/estf/terraform/gcp"

echo "--- TF destroy"
docker run --rm \
           -it \
           --name terraform \
           -v $TF_WORKSPACE:/workspace \
           -w /workspace \
           -e "TF_VAR_credentials=$TF_VAR_credentials" \
           -e "TF_VAR_os_image=$TF_VAR_os_image" \
           -e "TF_VAR_machine_type=$TF_VAR_machine_type" \
          hashicorp/terraform:latest destroy -auto-approve
