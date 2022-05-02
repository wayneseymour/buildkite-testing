#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for cloud kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -eu

# Valid test types/groups
testTypes="basic xpack"
declare -A testGroups
testGroups["basic"]="$(seq -s ' ' 1 12)"
testGroups["xpack"]="2 4 7 8 9 10 12 13 15 19 22 25 26 28 31"

# Allows input configuration
if ([ ! -z ${CI_GROUP:-} ] && [ -z ${TEST_TYPE:-} ]); then
  echo "CI_GROUP needs TEST_TYPE to be set, one of: ${testTypes// /,}"
  false
fi

if [ ! -z ${TEST_TYPE:-} ]; then
  echo "TEST_TYPE is set to: $TEST_TYPE"
  case " $testTypes " in (*" $TEST_TYPE "*) :;; (*) echo "Valid values: ${testTypes// /, }"; false;; esac
  testTypes=$TEST_TYPE
fi

if [ ! -z ${CI_GROUP:-} ]; then
  echo "CI_GROUP is set to: $CI_GROUP"
  case " ${testGroups[$TEST_TYPE]} " in (*" $CI_GROUP "*) :;; (*) echo "Valid values: ${testGroups[$TEST_TYPE]}"; false;; esac
  testGroups[${TEST_TYPE}]=${CI_GROUP}
fi

echo "steps:"

# Add kibana ci groups
for testType in $testTypes;
do
  for i in ${testGroups[$testType]};
  do
    metaId="${testType}-${i}"
    echo "  - group: \"${metaId} cloud kibana group\""
    echo "    key: \"cktg${i}\""
    echo "    steps:"
    echo "      - label: \"${metaId} create cloud deployment\""
    echo "        key: \"create_cloud_deployment${metaId}\""
    echo "        command: .buildkite/scripts/steps/estf/cloud/create_cloud_deployment.sh"
    echo "        env:"
    echo "          ESTF_GROUP_PARALLEL_JOB: ${i}"
    echo "          ESTF_KIBANA_TEST_TYPE: ${testType}"
    echo "          ESTF_META_ID: ${metaId}"
    echo "        agents:"
    echo "          queue: n2-4"
    echo "      - label: \"${metaId} run kibana functional tests\""
    echo "        key: \"run_kibana_tests${metaId}\""
    echo "        command: .buildkite/scripts/steps/estf/cloud/run_kibana_tests.sh"
    echo "        env:"
    echo "          ESTF_GROUP_PARALLEL_JOB: ${i}"
    echo "          ESTF_KIBANA_TEST_TYPE: ${testType}"
    echo "          ESTF_META_ID: ${metaId}"
    echo "        agents:"
    echo "          queue: n2-4"
    echo "        depends_on: \"create_cloud_deployment${metaId}\""
    echo "      - wait: ~"
    echo "        continue_on_failure: true"
    echo "      - plugins:"
    echo "          - junit-annotate#v2.0.2:"
    echo "              artifacts: target/junit/**/*"
    echo "        agents:"
    echo "          queue: n2-4"
    echo "      - label: \"${metaId} delete cloud deployment\""
    echo "        key: \"delete_cloud_deployment${metaId}\""
    echo "        command: .buildkite/scripts/steps/estf/cloud/shutdown_cloud_deployment.sh"
    echo "        env:"
    echo "          ESTF_GROUP_PARALLEL_JOB: ${i}"
    echo "          ESTF_META_ID: ${metaId}"
    echo "        agents:"
    echo "          queue: n2-4"
  done
done
