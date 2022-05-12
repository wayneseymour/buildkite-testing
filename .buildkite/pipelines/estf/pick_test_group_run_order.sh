#!/bin/bash

set -eu

source .buildkite/scripts/common/util.sh
source .buildkite/scripts/common/env.sh

echo '--- Pick Test Group Run Order'
node "$(dirname "${0}")/pick_test_group_run_order.js" || true

echo '-- Upload test steps'
.buildkite/scripts/steps/estf/cloud/ftr_steps.sh | buildkite-agent pipeline upload
