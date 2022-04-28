#!/usr/bin/env bash

set -euo pipefail

echo "Run kibana functional tests"

buildkite-agent meta-data exists "estf-kibana-hash"

# Clone kibana repo from git reference
git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git
cd kibana

# Checkout kibana commit
git checkout -f $(buildkite-agent meta-data get "estf-kibana-hash")

# Source env from kibana .buildkite directory
source .buildkite/scripts/common/util.sh

# Source env from kibana .buildkite directory
source .buildkite/scripts/common/env.sh

# Setup node from kibana .buildkite directory
source .buildkite/scripts/common/setup_node.sh

# Bootstrap from kibana .buildkite directory
source .buildkite/scripts/bootstrap.sh

ESTF_ELASTICSEARCH_URL=$(buildkite-agent meta-data get "estf-elasticsearch-url")
ESTF_KIBANA_URL=$(buildkite-agent meta-data get "estf-kibana-url")
ESTF_DEPLOYMENT_PASSWORD=$(buildkite-agent meta-data get "estf-deployment-password")

export TEST_ES_URL="${ESTF_ELASTICSEARCH_URL:0:8}elastic:${ESTF_DEPLOYMENT_PASSWORD}@${ESTF_ELASTICSEARCH_URL:8}"
export TEST_KIBANA_URL="${ESTF_KIBANA_URL:0:8}elastic:${ESTF_DEPLOYMENT_PASSWORD}@${ESTF_KIBANA_URL:8}"

# Run kibana tests on cloud
export TEST_CLOUD=1
export CI_GROUP=${CI_GROUP:-$((BUILDKITE_GROUP_PARALLEL_JOB))}
export JOB=kibana-oss-ciGroup${CI_GROUP}

echo "--- OSS CI Group $CI_GROUP run against ESS"

export ES_SECURITY_ENABLED=true

node scripts/functional_test_runner \
    --es-version $ESTF_CLOUD_VERSION \
    --exclude-tag skipCloud \
    --include-tag "ciGroup$CI_GROUP"
