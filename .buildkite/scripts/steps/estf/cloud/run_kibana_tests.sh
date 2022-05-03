#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

echo "Run kibana functional tests"

buildkite-agent meta-data exists "estf-kibana-hash-$ESTF_META_ID"

# Clone kibana repo from git reference
git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git
cd kibana

# Checkout kibana commit
git checkout -f $(buildkite-agent meta-data get "estf-kibana-hash-$ESTF_META_ID")

# Source env from kibana .buildkite directory
source .buildkite/scripts/common/util.sh

# Source env from kibana .buildkite directory
source .buildkite/scripts/common/env.sh

# Setup node from kibana .buildkite directory
source .buildkite/scripts/common/setup_node.sh

# Bootstrap from kibana .buildkite directory
source .buildkite/scripts/bootstrap.sh

# Set meta data for post command
is_test_execution_step

ESTF_ELASTICSEARCH_URL=$(buildkite-agent meta-data get "estf-elasticsearch-url-$ESTF_META_ID")
ESTF_KIBANA_URL=$(buildkite-agent meta-data get "estf-kibana-url-$ESTF_META_ID")
ESTF_DEPLOYMENT_PASSWORD=$(buildkite-agent meta-data get "estf-deployment-password-$ESTF_META_ID")

export TEST_ES_URL="${ESTF_ELASTICSEARCH_URL:0:8}elastic:${ESTF_DEPLOYMENT_PASSWORD}@${ESTF_ELASTICSEARCH_URL:8}"
export TEST_KIBANA_URL="${ESTF_KIBANA_URL:0:8}elastic:${ESTF_DEPLOYMENT_PASSWORD}@${ESTF_KIBANA_URL:8}"

# Run kibana tests on cloud
export TEST_CLOUD=1
export JOB=kibana-$ESTF_META_ID

includeTag="$ESTF_KIBANA_INCLUDE_TAG"

# Run basic group
if [[ "$ESTF_KIBANA_TEST_TYPE" == "basic" ]]; then
    export ES_SECURITY_ENABLED=true
    echo "--- Basic tests run against ESS"
    eval node scripts/functional_test_runner \
            --es-version $ESTF_CLOUD_VERSION \
            --exclude-tag skipCloud " $includeTag"
fi

# Run xpack group
if [[ "$ESTF_KIBANA_TEST_TYPE" == "xpack" ]]; then
    cd x-pack
    echo "--- Xpack tests run against ESS"
    eval node scripts/functional_test_runner \
            --es-version $ESTF_CLOUD_VERSION \
            --exclude-tag skipCloud " $includeTag"
fi
