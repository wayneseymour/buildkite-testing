#!/usr/bin/env bash

set -euo pipefail

# -- From github.com/elastic/kibana repo .buildkite/scripts/lifecycle/post_command.sh

echo '--- Agent Debug Info'
node .buildkite/scripts/lifecycle/print_agent_links.js || true

IS_TEST_EXECUTION_STEP="$(buildkite-agent meta-data get "${BUILDKITE_JOB_ID}_is_test_execution_step" --default '')"

if [[ "$IS_TEST_EXECUTION_STEP" == "true" ]]; then
  cd kibana
  echo "--- Upload Artifacts"
  buildkite-agent artifact upload 'target/junit/**/*'
  buildkite-agent artifact upload 'target/kibana-*'
  buildkite-agent artifact upload 'target/kibana-security-solution/**/*.png'
  buildkite-agent artifact upload 'target/test-metrics/*'
  buildkite-agent artifact upload 'target/test-suites-ci-plan.json'
  buildkite-agent artifact upload 'test/**/screenshots/diff/*.png'
  buildkite-agent artifact upload 'test/**/screenshots/failure/*.png'
  buildkite-agent artifact upload 'test/**/screenshots/session/*.png'
  buildkite-agent artifact upload 'test/functional/failure_debug/html/*.html'
  buildkite-agent artifact upload 'x-pack/test/**/screenshots/diff/*.png'
  buildkite-agent artifact upload 'x-pack/test/**/screenshots/failure/*.png'
  buildkite-agent artifact upload 'x-pack/test/**/screenshots/session/*.png'
  buildkite-agent artifact upload 'x-pack/test/functional/apps/reporting/reports/session/*.pdf'
  buildkite-agent artifact upload 'x-pack/test/functional/failure_debug/html/*.html'

  echo "--- Run Failed Test Reporter"

  echo "--- Source env and utils from kibana .buildkite directory"
  source .buildkite/scripts/common/util.sh
  source .buildkite/scripts/common/env.sh

  echo "--- Setup node from kibana .buildkite directory"
  source .buildkite/scripts/common/setup_node.sh

  echo '--- Install buildkite dependencies'
  cd '.buildkite'
  rm -rf node_modules
  rm package-lock.json
  npm cache clean --force
  retry 5 15 npm install --verbose
  cd ..

  node scripts/report_failed_tests --no-github-update --build-url="${BUILDKITE_BUILD_URL}#${BUILDKITE_JOB_ID}" 'target/junit/**/*.xml'

  if [[ -d 'target/test_failures' ]]; then
    buildkite-agent artifact upload 'target/test_failures/**/*'
    node .buildkite/scripts/lifecycle/annotate_test_failures.js
  fi
fi
