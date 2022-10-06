#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run stack tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

echo "--- Run stack tests"

githubOwner="$(get_github_owner)"
githubRepo="$(get_github_repo elastic-stack-testing)"
githubRefRepo="$(get_github_ref_repo)"
githubBranch="$(get_github_branch)"
githubPrNum="$(get_github_pr_num)"
excludeTests="$(get_excluded_tests)"

echo "--- Clone estf repo and chdir"
git clone "https://github.com/$githubOwner/$githubRepo"
cd elastic-stack-testing

echo "--- Checkout elastic-stack-testing"
if [[ ! -z "$githubPrNum" ]]; then
  prefix="pr-"
  num=${githubPrNum#"$prefix"}
  git fetch origin pull/$num/head:pr-$num
  git checkout pr-$num
elif [[ ! -z "$githubBranch" ]]; then
  git checkout -f "$githubBranch"
else
  buildkite-agent meta-data exists "estf-stack-hash-$ESTF_META_ID"
  git checkout -f $(buildkite-agent meta-data get "estf-stack-hash-$ESTF_META_ID")
fi

echo "--- Run ansible playbook"
VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
retry 5 30 vault login -no-print "$VAULT_TOKEN"

export GCP_AUTH_KIND="serviceaccount"
GCP_SERVICE_ACCOUNT_CONTENTS="$(vault kv get --field policy secret/stack-testing/estf-gcp)"
export GCP_SERVICE_ACCOUNT_CONTENTS

# TODO: this needs to be fixed from RM
export ES_BUILD_URL=snapshots.elastic.co/${ESTF_BUILD_ID}

export AIT_UUT=$(buildkite-agent meta-data get "estf-tf-ip-$ESTF_META_ID")

OUTPUT_FILE=$(mktemp --suffix ".json")
echo $GCP_SERVICE_ACCOUNT_CONTENTS > $OUTPUT_FILE
gcloud auth activate-service-account --key-file="$OUTPUT_FILE"
rm $OUTPUT_FILE
VM_NAME=$(gcloud compute instances list --project elastic-automation --filter $AIT_UUT | awk 'FNR == 2 {print $1}')
echo -ne '\n' | gcloud compute ssh $VM_NAME --ssh-key-file=/tmp/gcpkey --zone "us-central1-a" --project "elastic-automation"
export ANSIBLE_PRIVATE_KEY_FILE=/tmp/gcpkey

./playbooks/stack_testing/ci/buildkite_stack_testing.sh
