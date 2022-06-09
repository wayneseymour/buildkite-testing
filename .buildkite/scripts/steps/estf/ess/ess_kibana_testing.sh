#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests pn ESS deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

trap "cleanup" EXIT

cleanup() {
  dir=$(buildkite-agent meta-data get "homedir")
  cd $dir
  source .buildkite/scripts/steps/estf/ess/ess_shutdown_deployment.sh
}

buildkite-agent meta-data set "homedir" "$(pwd)"

source .buildkite/scripts/steps/estf/ess/ess_create_deployment.sh
source .buildkite/scripts/steps/estf/ess/ess_run_kibana_tests.sh
