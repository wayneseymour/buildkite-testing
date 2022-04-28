#!/bin/bash

set -eu

echo "steps:"

# Add kibana oss ci groups
for i in `seq 1 12`;
do
  echo "  - group: \"Cloud Kibana Tests Group ${i}\""
  echo "    key: \"cktg${i}\""
  echo "    steps:"
  echo "      - label: \"Create Cloud Deployment\""
  echo "        key: \"create_cloud_deployment${i}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/create_cloud_deployment.sh"
  echo "        env:"
  echo "          BUILDKITE_GROUP_PARALLEL_JOB: ${i}"
  echo "        agents:"
  echo "          queue: n2-4"
  echo "      - label: \"Run Kibana Functional Tests\""
  echo "        key: \"run_kibana_tests${i}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/run_kibana_tests.sh"
  echo "        env:"
  echo "          BUILDKITE_GROUP_PARALLEL_JOB: ${i}"
  echo "        agents:"
  echo "          queue: n2-4"
  echo "        depends_on: \"create_cloud_deployment${i}\""
  echo "      - wait: ~"
  echo "        continue_on_failure: true"
  echo "      - label: \"Delete Cloud Deployment\""
  echo "        key: \"delete_cloud_deployment${i}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/shutdown_cloud_deployment.sh"
  echo "        agents:"
  echo "          queue: n2-4"
done
