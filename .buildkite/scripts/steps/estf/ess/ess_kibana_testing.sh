#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests on ESS deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

trap "cleanup" EXIT

cleanup() {
  dir=$(buildkite-agent meta-data get "estf-homedir-$ESTF_META_ID")
  cd $dir
  source .buildkite/scripts/steps/estf/ess/ess_shutdown_deployment.sh
}

buildkite-agent meta-data set "estf-homedir-$ESTF_META_ID" "$(pwd)"

source .buildkite/scripts/steps/estf/ess/ess_create_deployment.sh
source .buildkite/scripts/steps/estf/kibana/run_kibana_tests.sh