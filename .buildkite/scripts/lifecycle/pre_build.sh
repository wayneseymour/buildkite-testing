#!/usr/bin/env bash

set -euo pipefail

source .buildkite/scripts/common/util.sh

export CI_STATS_TOKEN="$(retry 5 5 vault read -field=api_token secret/kibana-issues/dev/kibana_ci_stats)"
export CI_STATS_HOST="$(retry 5 5 vault read -field=api_host secret/kibana-issues/dev/kibana_ci_stats)"

node "$(dirname "${0}")/ci_stats_start.js"

# On retry, clear the previously published test_failure annotations
rmTestFailureAnnotations=$(buildkite-agent meta-data exists "removedTestFailureAnnotations")
if [[ "$rmTestFailureAnnotations" != "0" &&
      "${BUILDKITE_RETRY_COUNT:-0}" == "1" ]]; then
  buildkite-agent annotation remove --context "test_failures"
  buildkite-agent meta-data set "removedTestFailureAnnotations" "true"
fi
