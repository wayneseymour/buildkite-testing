#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests pn ESS deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

trap "chdir; source .buildkite/scripts/steps/estf/ess/ess_shutdown_deployment.sh" EXIT

chdir() {
  dir=$(pwd)
  if [[ $(basename $dir) == "kibana" ]]; then
     cd ../
  fi
}

source .buildkite/scripts/common/util.sh

echo "--- Create ESS Deployment"

VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
retry 5 30 vault login -no-print "$VAULT_TOKEN"

EC_API_KEY="$(vault kv get --field apiKey secret/stack-testing/estf-cloud)"
export EC_API_KEY

ESTF_DEPLOYMENT_NAME="ESTF_Deployment_CI_$(uuidgen)"
ESTF_PLAN_FILE=".buildkite/scripts/steps/estf/ess/plans/ess_default_plan.json"
OUTPUT_FILE=$(mktemp --suffix ".json")

if [[ ! -z "${ESTF_PLAN_SETTINGS:-}" ]] && [[ "${ESTF_PLAN_SETTINGS:-}" != "none" ]]; then
  settingsDir=".buildkite/scripts/steps/estf/ess/settings"
  for plan in ${ESTF_PLAN_SETTINGS}; do
    settings=$(cat $settingsDir/$plan)
    branch=$(get_branch_from_version)
    ext=".json"
    verfile="$settingsDir/${plan%%$ext*}_$branch$ext"
    if [[ -f $verfile ]]; then
      settings=$(cat $verfile)
    fi
    cat <<< $(jq ".resources.kibana[0].plan.kibana.user_settings_json += $settings" $ESTF_PLAN_FILE) > $ESTF_PLAN_FILE
  done
fi

ecctl deployment create --track --output json --name $ESTF_DEPLOYMENT_NAME \
                        --version $ESTF_CLOUD_VERSION --file $ESTF_PLAN_FILE &> "$OUTPUT_FILE"

ESTF_DEPLOYMENT_ID=$(jq -sr '.[0].id' "$OUTPUT_FILE")
ESTF_DEPLOYMENT_USERNAME=$(jq -sr '.[0].resources[0].credentials.username' "$OUTPUT_FILE")
ESTF_DEPLOYMENT_PASSWORD=$(jq -sr '.[0].resources[0].credentials.password' "$OUTPUT_FILE")
ESTF_KIBANA_URL=$(ecctl deployment show "$ESTF_DEPLOYMENT_ID" --kind kibana | jq -r '.info.metadata.aliased_url')
ESTF_ELASTICSEARCH_URL=$(ecctl deployment show "$ESTF_DEPLOYMENT_ID" --kind elasticsearch | jq -r '.info.metadata.aliased_url')
ESTF_KIBANA_HASH=$(curl -s -u "$ESTF_DEPLOYMENT_USERNAME:$ESTF_DEPLOYMENT_PASSWORD" $ESTF_KIBANA_URL/api/status | jq -r .version.build_hash)

buildkite-agent meta-data set "estf-deployment-id-$ESTF_META_ID" $ESTF_DEPLOYMENT_ID
buildkite-agent meta-data set "estf-kibana-hash-$ESTF_META_ID" $ESTF_KIBANA_HASH
buildkite-agent meta-data set "estf-elasticsearch-url-$ESTF_META_ID" $ESTF_ELASTICSEARCH_URL
buildkite-agent meta-data set "estf-kibana-url-$ESTF_META_ID" $ESTF_KIBANA_URL
buildkite-agent meta-data set "estf-deployment-password-$ESTF_META_ID" $ESTF_DEPLOYMENT_PASSWORD

cat << EOF | buildkite-agent annotate --style "info" --context cloud_$ESTF_META_ID
  $ESTF_META_ID deployment id: $ESTF_DEPLOYMENT_ID
EOF

echo "--- Run Kibana Functional Tests"

source .buildkite/scripts/common/ftr.sh

buildkite-agent meta-data exists "estf-kibana-hash-$ESTF_META_ID"

echo "--- Clone kibana repo and chdir"
git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git
cd kibana

echo "--- Checkout kibana commit"
git checkout -f $(buildkite-agent meta-data get "estf-kibana-hash-$ESTF_META_ID")

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

if [[ ! -z "${ESTF_FTR_CONFIGS:-}" ]]; then
  run_ftr_cloud_configs
else
  run_ftr_cloud_ci_groups
fi
