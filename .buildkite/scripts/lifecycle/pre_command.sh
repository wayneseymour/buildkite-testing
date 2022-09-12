#!/usr/bin/env bash

set -euo pipefail

source .buildkite/scripts/common/util.sh

BUILDKITE_TOKEN="$(retry 5 5 vault read -field=buildkite_token_all_jobs secret/kibana-issues/dev/buildkite-ci)"
export BUILDKITE_TOKEN

echo '--- Install buildkite dependencies'
cd '.buildkite'
retry 5 15 npm ci
cd ..

echo '--- Agent Debug/SSH Info'
node .buildkite/scripts/lifecycle/print_agent_links.js || true

if [[ "$(curl -is metadata.google.internal || true)" ]]; then
  echo ""
  echo "To SSH into this agent, run:"
  echo "gcloud compute ssh --tunnel-through-iap --project elastic-kibana-ci --zone \"$(curl -sH Metadata-Flavor:Google http://metadata.google.internal/computeMetadata/v1/instance/zone)\" \"$(curl -sH Metadata-Flavor:Google http://metadata.google.internal/computeMetadata/v1/instance/name)\""
  echo ""
fi

# Setup CI Stats
{
  CI_STATS_BUILD_ID="$(buildkite-agent meta-data get ci_stats_build_id --default '')"
  export CI_STATS_BUILD_ID

  if [[ "$CI_STATS_BUILD_ID" ]]; then
    echo "CI Stats Build ID: $CI_STATS_BUILD_ID"

    CI_STATS_TOKEN="$(retry 5 5 vault read -field=api_token secret/kibana-issues/dev/kibana_ci_stats)"
    export CI_STATS_TOKEN

    CI_STATS_HOST="$(retry 5 5 vault read -field=api_host secret/kibana-issues/dev/kibana_ci_stats)"
    export CI_STATS_HOST

    KIBANA_CI_STATS_CONFIG=$(jq -n \
      --arg buildId "$CI_STATS_BUILD_ID" \
      --arg apiUrl "https://$CI_STATS_HOST" \
      --arg apiToken "$CI_STATS_TOKEN" \
      '{buildId: $buildId, apiUrl: $apiUrl, apiToken: $apiToken}' \
    )
    export KIBANA_CI_STATS_CONFIG
  fi
}

KIBANA_CI_REPORTER_KEY=$(retry 5 5 vault read -field=value secret/kibana-issues/dev/kibanamachine-reporter)
export KIBANA_CI_REPORTER_KEY

# Setup Failed Test Reporter Elasticsearch credentials
{
  TEST_FAILURES_ES_CLOUD_ID=$(retry 5 5 vault read -field=cloud_id secret/kibana-issues/dev/failed_tests_reporter_es)
  export TEST_FAILURES_ES_CLOUD_ID

  TEST_FAILURES_ES_USERNAME=$(retry 5 5 vault read -field=username secret/kibana-issues/dev/failed_tests_reporter_es)
  export TEST_FAILURES_ES_USERNAME

  TEST_FAILURES_ES_PASSWORD=$(retry 5 5 vault read -field=password secret/kibana-issues/dev/failed_tests_reporter_es)
  export TEST_FAILURES_ES_PASSWORD
}

PIPELINE_PRE_COMMAND=${PIPELINE_PRE_COMMAND:-".buildkite/scripts/lifecycle/pipelines/$BUILDKITE_PIPELINE_SLUG/pre_command.sh"}
if [[ -f "$PIPELINE_PRE_COMMAND" ]]; then
  source "$PIPELINE_PRE_COMMAND"
fi
