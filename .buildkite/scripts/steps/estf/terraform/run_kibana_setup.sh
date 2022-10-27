#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana operating system tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/steps/estf/ansible/ansible_setup.sh

echo "--- Run kibana operating system tests"
export ESTF_PUBLIC_IP=$(buildkite-agent meta-data get "estf-tf-ip-$ESTF_META_ID")
./playbooks/kibana/ci/buildkite_os_testing.sh

OUTPUT_FILE="/tmp/$ESTF_META_ID"

echo "--- Read instance file vars"
while IFS=": " read -r key value
do
  case $key in
    user)
      ESTF_DEPLOYMENT_USERNAME=$value
      ;;
    password)
      ESTF_DEPLOYMENT_PASSWORD=$value
      ;;
    kibana_url)
      ESTF_KIBANA_URL=$value
      ;;
    elasticsearch_url)
      ESTF_ELASTICSEARCH_URL=$value
      ;;
    *)
      ;;
  esac
done < "$OUTPUT_FILE"

echo "--- Get kibana hash"
ESTF_KIBANA_HASH=$(curl --insecure -s -u "$ESTF_DEPLOYMENT_USERNAME:$ESTF_DEPLOYMENT_PASSWORD" $ESTF_KIBANA_URL/api/status | jq -r .version.build_hash)

echo "--- Set metadata"
buildkite-agent meta-data set "estf-kibana-hash-$ESTF_META_ID" $ESTF_KIBANA_HASH
buildkite-agent meta-data set "estf-elasticsearch-url-$ESTF_META_ID" $ESTF_ELASTICSEARCH_URL
buildkite-agent meta-data set "estf-kibana-url-$ESTF_META_ID" $ESTF_KIBANA_URL
buildkite-agent meta-data set "estf-deployment-password-$ESTF_META_ID" $ESTF_DEPLOYMENT_PASSWORD

echo "--- Chdir uplevel"
cd ../
