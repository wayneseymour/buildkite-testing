#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

echo "--- Run kibana functional tests"

source .buildkite/scripts/common/ftr.sh

buildkite-agent meta-data exists "estf-kibana-hash-$ESTF_META_ID"

echo "--- Clone kibana repo and chdir"
git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git
cd kibana

# Checkout kibana commit
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

ESTF_ELASTICSEARCH_HOST_PORT=${ESTF_ELASTICSEARCH_URL#*://}
ESTF_KIBANA_HOST_PORT=${ESTF_KIBANA_URL#*://}

export TEST_KIBANA_PROTOCOL=${ESTF_KIBANA_URL%://*}
export TEST_KIBANA_PORT=${ESTF_KIBANA_HOST_PORT#*:}
export TEST_KIBANA_USERNAME=elastic
export TEST_KIBANA_PASS=${ESTF_DEPLOYMENT_PASSWORD}
export TEST_KIBANA_HOSTNAME=${ESTF_KIBANA_HOST_PORT%:*}

export TEST_ES_PROTOCOL=${ESTF_ELASTICSEARCH_URL%://*}
export TEST_ES_PORT=${ESTF_ELASTICSEARCH_HOST_PORT#*:}
export TEST_ES_USERNAME=elastic
export TEST_ES_PASS=${ESTF_DEPLOYMENT_PASSWORD}
export TEST_ES_HOSTNAME=${ESTF_ELASTICSEARCH_HOST_PORT%:*}

if [[ ! -z "${ESTF_FTR_CONFIGS:-}" ]]; then
  run_ftr_cloud_configs
else
  run_ftr_cloud_ci_groups
fi
