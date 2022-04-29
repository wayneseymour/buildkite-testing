#!/bin/bash

set -eu

echo "steps:"

# Add kibana oss ci groups
testType="oss"
for i in `seq 1 2`;
do
  metaId="${testType}-${i}"
  echo "  - group: \"Cloud Kibana ${testType^^} Test Group ${i}\""
  echo "    key: \"cktg${i}\""
  echo "    steps:"
  echo "      - label: \"Create Cloud Deployment\""
  echo "        key: \"create_cloud_deployment${i}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/create_cloud_deployment.sh"
  echo "        env:"
  echo "          ESTF_GROUP_PARALLEL_JOB: ${i}"
  echo "          ESTF_META_ID: ${metaId}"
  echo "        agents:"
  echo "          queue: n2-4"
  echo "      - label: \"Run Kibana Functional Tests\""
  echo "        key: \"run_kibana_tests${i}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/run_kibana_tests.sh"
  echo "        env:"
  echo "          ESTF_GROUP_PARALLEL_JOB: ${i}"
  echo "          ESTF_META_ID: ${metaId}"
  echo "        agents:"
  echo "          queue: n2-4"
  echo "        depends_on: \"create_cloud_deployment${i}\""
  echo "      - wait: ~"
  echo "        continue_on_failure: true"
  echo "      - label: \"Delete Cloud Deployment\""
  echo "        key: \"delete_cloud_deployment${i}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/shutdown_cloud_deployment.sh"
  echo "        env:"
  echo "          ESTF_GROUP_PARALLEL_JOB: ${i}"
  echo "          ESTF_META_ID: ${metaId}"
  echo "        agents:"
  echo "          queue: n2-4"
done
