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

echo "Debug after kibana playbook"
OUTPUT_FILE="/tmp/$ESTF_META_ID"

echo "--Output file: $OUTPUT_FILE"
ls -l $OUTPUT_FILE
whoami

echo "-- Read vars"
read user < $OUTPUT_FILE ESTF_DEPLOYMENT_USERNAME
read password < $OUTPUT_FILE ESTF_DEPLOYMENT_PASSWORD
read kibana_url < $OUTPUT_FILE ESTF_KIBANA_URL
read elasticsearch_url < $OUTPUT_FILE ESTF_ELASTICSEARCH_URL

echo "-- Get kibana hash"
ESTF_KIBANA_HASH=$(curl -s -u "$ESTF_DEPLOYMENT_USERNAME:$ESTF_DEPLOYMENT_PASSWORD" $ESTF_KIBANA_URL/api/status | jq -r .version.build_hash)

echo "--- Set metadata"
buildkite-agent meta-data set "estf-kibana-hash-$ESTF_META_ID" $ESTF_KIBANA_HASH
buildkite-agent meta-data set "estf-elasticsearch-url-$ESTF_META_ID" $ESTF_ELASTICSEARCH_URL
buildkite-agent meta-data set "estf-kibana-url-$ESTF_META_ID" $ESTF_KIBANA_URL
buildkite-agent meta-data set "estf-deployment-password-$ESTF_META_ID" $ESTF_DEPLOYMENT_PASSWORD

echo "-- chdir uplevel"
cd ../
