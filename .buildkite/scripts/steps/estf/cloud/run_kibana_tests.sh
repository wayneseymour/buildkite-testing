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
source .buildkite/scripts/common/env.sh

# Setup node from kibana .buildkite directory
source .buildkite/scripts/common/setup_node.sh

# Bootstrap from kibana .buildkite directory
source .buildkite/scripts/bootstrap.sh

# Disable checks reporter
CHECKS_REPORTER_ACTIVE="false"

# Run ossGrp test from kibana .buildkite directory
source .buildkite/scripts/steps/functional/oss_cigroup.sh
