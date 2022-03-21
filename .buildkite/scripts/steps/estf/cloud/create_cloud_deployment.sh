#!/usr/bin/env bash

set -euo pipefail

source .buildkite/scripts/common/util.sh

echo "Create cloud deployment"

VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
echo "after vault role id"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
echo "after vault secret id"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
echo "after toek"
retry 5 30 vault login -no-print "$VAULT_TOKEN"
echo "after login"

EC_API_KEY="$(vault kv get --field apiKey secret/stack-testing/estf-cloud)"
export EC_API_KEY
echo "ec key setup"

ESTF_DEPLOYMENT_NAME="ESTF_Deployment_CI_$(uuidgen)"
ESTF_PLAN_FILE="estf_cloud_plan.json"
OUTPUT_FILE=$(mktemp --suffix ".json")

echo "INPUT"
echo $ESTF_PLAN_FILE
echo $ESTF_CLOUD_VERSION
echo $(pwd)
echo "END"
ecctl deployment create --track --output json --name $ESTF_DEPLOYMENT_NAME \
                        --version $ESTF_CLOUD_VERSION --file $ESTF_PLAN_FILE &> "$OUTPUT_FILE"

echo "after create"
ESTF_DEPLOYMENT_ID=$(jq -sr '.[0].id' "$OUTPUT_FILE")
ESTF_DEPLOYMENT_USERNAME=$(jq -sr '.[0].resources[0].credentials.username' "$OUTPUT_FILE")
ESTF_DEPLOYMENT_PASSWORD=$(jq -sr '.[0].resources[0].credentials.password' "$OUTPUT_FILE")

retry 5 15 vault write "secret/stack-testing/$ESTF_DEPLOYMENT_ID" username="$ESTF_DEPLOYMENT_USERNAME" password="$ESTF_DEPLOYMENT_PASSWORD"

ESTF_KIBANA_URL=$(ecctl deployment show "$ESTF_DEPLOYMENT_ID" --kind kibana | jq -r '.info.metadata.aliased_url')
ESTF_ELASTICSEARCH_URL=$(ecctl deployment show "$ESTF_DEPLOYMENT_ID" --kind elasticsearch | jq -r '.info.metadata.aliased_url')

ESTF_KIBANA_HASH=$(curl -s -u "$ESTF_DEPLOYMENT_USERNAME:$ESTF_DEPLOYMENT_PASSWORD" $ESTF_KIBANA_URL/api/status | jq -r .version.build_hash)

buildkite-agent meta-data set "estf-deployment-id" $ESTF_DEPLOYMENT_ID
buildkite-agent meta-data set "estf-kibana-hash" $ESTF_KIBANA_HASH

cat << EOF | buildkite-agent annotate --style "info" --context cloud
  Deployment Id: $ESTF_DEPLOYMENT_ID
EOF
