#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

echo "--- Run kibana functional tests"

source .buildkite/scripts/common/ftr.sh

echo "--- Clone kibana repo and chdir"

githubOwner="$(get_github_owner)"
githubRepo="$(get_github_repo)"
githubRefRepo="$(get_github_ref_repo)"
githubBranch="$(get_github_branch)"
githubPrNum="$(get_github_pr_num)"

git clone --reference "$githubRefRepo" "https://github.com/$githubOwner/$githubRepo"
cd kibana

echo "--- Checkout kibana"
if [[ ! -z "$githubPrNum" ]]; then
  prefix="pr-"
  num=${githubPrNum#"$prefix"}
  git fetch origin pull/$num/head:pr-$num
  git checkout pr-$num
elif [[ ! -z "$githubBranch" ]]; then
  git checkout -f "$githubBranch"
else
  buildkite-agent meta-data exists "estf-kibana-hash-$ESTF_META_ID"
  git checkout -f $(buildkite-agent meta-data get "estf-kibana-hash-$ESTF_META_ID")
fi

echo "--- Source env and utils from kibana .buildkite directory"
source .buildkite/scripts/common/util.sh
source .buildkite/scripts/common/env.sh

echo "--- Setup node from kibana .buildkite directory"
source .buildkite/scripts/common/setup_node.sh

echo "--- Bootstrap from kibana .buildkite directory"
source .buildkite/scripts/bootstrap.sh

# Set meta data for post command
is_test_execution_step

ESTF_ELASTICSEARCH_URL=$(buildkite-agent meta-data get "estf-elasticsearch-url-$ESTF_META_ID")
ESTF_KIBANA_URL=$(buildkite-agent meta-data get "estf-kibana-url-$ESTF_META_ID")
ESTF_DEPLOYMENT_PASSWORD=$(buildkite-agent meta-data get "estf-deployment-password-$ESTF_META_ID")

ESTF_ELASTICSEARCH_HOST_PORT="${ESTF_ELASTICSEARCH_URL#*://}"
ESTF_KIBANA_HOST_PORT="${ESTF_KIBANA_URL#*://}"

if [[ "$ESTF_ELASTICSEARCH_HOST_PORT" == *":"* ]]; then
  ESTF_ELASTICSEARCH_PORT="${ESTF_ELASTICSEARCH_HOST_PORT#*:}"
fi

if [[ "$ESTF_KIBANA_HOST_PORT" == *":"* ]]; then
  ESTF_KIBANA_PORT="${ESTF_KIBANA_HOST_PORT#*:}"
fi

export TEST_KIBANA_PROTOCOL="${ESTF_KIBANA_URL%://*}"
export TEST_KIBANA_PORT="${ESTF_KIBANA_PORT:-443}"
export TEST_KIBANA_USERNAME="elastic"
export TEST_KIBANA_PASS="${ESTF_DEPLOYMENT_PASSWORD}"
export TEST_KIBANA_HOSTNAME="${ESTF_KIBANA_HOST_PORT%:*}"

export TEST_ES_PROTOCOL="${ESTF_ELASTICSEARCH_URL%://*}"
export TEST_ES_PORT="${ESTF_ELASTICSEARCH_PORT:-443}"
export TEST_ES_USERNAME="elastic"
export TEST_ES_PASS="${ESTF_DEPLOYMENT_PASSWORD}"
export TEST_ES_HOSTNAME="${ESTF_ELASTICSEARCH_HOST_PORT%:*}"

if [[ ! -z "${ESTF_VISUAL_TESTS:-}" ]]; then
  echo "--- Setup Percy Token"
  VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
  VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
  VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
  retry 5 30 vault login -no-print "$VAULT_TOKEN"
  if [[ "$ESTF_KIBANA_TEST_TYPE" == "xpack" ]]; then
    PERCY_TOKEN="$(vault kv get --field apiKey secret/stack-testing/percy-rm-default)"
  elif [[ "$ESTF_KIBANA_TEST_TYPE" == "basic" ]]; then
    PERCY_TOKEN="$(vault kv get --field apiKey secret/stack-testing/percy-rm-oss)"
  fi
  export PERCY_TOKEN
  run_ftr_cloud_visual_tests
elif [[ ! -z "${ESTF_FTR_CONFIGS:-}" ]]; then
  run_ftr_cloud_configs
else
  run_ftr_cloud_ci_groups
fi
