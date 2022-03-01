#!/usr/bin/env bash

set -euo pipefail

echo "Setup"

# Clone repo
git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git
cd kibana

# Checkout commit
git checkout -f 9fc24880156ba07f6e8f8a58f995875d30127ce7

# Source env
source .buildkite/scripts/common/env.sh

# Setup node
source .buildkite/scripts/common/setup_node.sh

# Bootstrap
source .buildkite/scripts/bootstrap.sh
