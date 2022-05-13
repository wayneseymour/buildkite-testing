#!/bin/bash

set -eu

source .buildkite/scripts/common/util.sh

if [[ $(is_version_ge "$ESTF_CLOUD_VERSION" "8.3") == 1 ]]; then
  # Clone kibana repo from git reference
  echo "--- Clone kibana repo and chdir"
  git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git

  # TODO: checkout branch

  echo "--- Source env and utils from kibana .buildkite directory"
  source .buildkite/scripts/common/util.sh
  source .buildkite/scripts/common/env.sh

  echo '--- Pick Test Group Run Order'
  node "$(dirname "${0}")/pick_test_group_run_order.js" || true
fi

echo '-- Upload Commands'
$ESTF_UPLOAD_SCRIPT | buildkite-agent pipeline upload
