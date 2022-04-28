#!/bin/bash

set -eu

echo "steps:"

# Add kibana oss ci groups
for i in `seq 1 2`;
do
  yml="  - group: \"Cloud Kibana Tests Group ${i}\"
    key: \"cktg${i}\"
    steps:
      - label: \"Create Cloud Deployment\"
        key: \"create_cloud_deployment${i}\"
        command: .buildkite/scripts/steps/estf/cloud/create_cloud_deployment.sh
        env:
          BUILDKITE_GROUP_PARALLEL_JOB: ${i}
        agents:
          queue: n2-4
      - label: \"Run Kibana Functional Tests\"
        key: \"run_kibana_tests${i}\"
        command: .buildkite/scripts/steps/estf/cloud/run_kibana_tests.sh
        env:
          BUILDKITE_GROUP_PARALLEL_JOB: ${i}
        agents:
          queue: n2-4
        depends_on: \"create_cloud_deployment${i}\"
      - wait: ~
        continue_on_failure: true
      - label: \"Delete Cloud Deployment\"
        key: \"delete_cloud_deployment${i}\"
        command: .buildkite/scripts/steps/estf/cloud/shutdown_cloud_deployment.sh
        agents:
          queue: n2-4
  "
  echo -n "$yml"
done
