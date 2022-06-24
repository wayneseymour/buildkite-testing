#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana flaky runner against ESS
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/common/util.sh

# Limits
LIMIT_NUM_EXECUTIONS=50
LIMIT_NUM_CONFIGS=3

githubOwner="$(get_github_owner)"
githubBranch="$(get_github_branch)"
githubPrNum="$(get_github_pr_num)"
cloudVersion="$(get_cloud_version)"
numExecutions="$(get_num_executions)"
testConfigs="$(get_test_configs)"
basicCiGroups="$(get_basic_ci_groups)"
xpackCiGroups="$(get_xpack_ci_groups)"

if [[ "$githubOwner" != "elastic" ]] &&
   [[ -z "$githubBranch" ]] ||
   [[ -z "$githubPrNum" ]] ||
   [[ -z "$cloudVersion" ]]; then
  echo "Cloud version and branch or PR number must be set"
  false
fi

if [[ $(is_version_ge "$cloudVersion" "8.3") == 1 ]] &&
   [[ -z $testConfigs ]]; then
  echo "Test configs must be set"
  false
else
  if [[ -z "$testConfigs" ]] &&
     [[ -z "$basicCiGroups" ]] &&
     [[ -z "$xpackCiGroups" ]]; then
    echo "Basic CI Group, Xpack CI Group or Xpack Extended Config must be set"
    false
  fi
fi

TEST_TYPE=""
CI_GROUP=""
if [[ $(is_version_ge "$cloudVersion" "8.3") == 0 ]]; then
  TEST_TYPE="xpackext"
  if [[ ! -z $basicCiGroups ]]; then
    TEST_TYPE="basic"
    CI_GROUP=$basicCiGroups
  elif [[ ! -z $xpackCiGroups ]]; then
    TEST_TYPE="xpack"
    CI_GROUP=$xpackCiGroups
  fi
fi

if [[ $numExecutions -gt $LIMIT_NUM_EXECUTIONS ]]; then
  echo "Number of executions is limted to $LIMIT_NUM_EXECUTIONS"
  false
fi

MAX_GROUPS=$(( $numExecutions / 5 ))
REPEAT_TESTS=5
if [[ $MAX_GROUPS == 0 ]]; then
  MAX_GROUPS=1
  REPEAT_TESTS=0
fi

if [[ ! -z $testConfigs ]]; then
  configArr=($testConfigs)
  if [[ ${#configArr[@]} -gt $LIMIT_NUM_CONFIGS ]]; then
    echo "Number of configurations is limted to $LIMIT_NUM_CONFIGS"
    false
  fi
  prefix1="test/"
  prefix2="x-pack/test/"
  for config in "${configArr[@]}"; do
    if [[ ! ("$config" =~ ^$prefix1.*\/config\.(j|t)s) ]] &&
      [[ ! ("$config" =~ ^$prefix2.*\/config\.(j|t)s) ]]; then
      echo "Invalid configuration format: $config"
      false
    fi
  done
fi

echo "  - command: .buildkite/scripts/lifecycle/pre_build.sh"
echo "    label: Pre-Build"
echo "    timeout_in_minutes: 10"
echo "    agents:"
echo "      queue: kibana-default"
echo "  - wait"
for i in $(seq -s ' ' 1 $MAX_GROUPS); do
  echo "  - command: .buildkite/pipelines/estf/pick_test_group_run_order.sh"
  echo "    label: \"Pick Test Groups $i - Repeats $REPEAT_TESTS\""
  echo "    agents:"
  echo "      queue: kibana-default"
  echo "    env:"
  echo "      ESTF_UPLOAD_SCRIPT: \".buildkite/scripts/steps/estf/ess/ess_upload_steps.sh\""
  echo "      TEST_TYPE: $TEST_TYPE"
  echo "      CI_GROUP: $CI_GROUP"
  echo "      REPEAT_TESTS: $REPEAT_TESTS"
  echo "      FUNCTIONAL_MAX_MINUTES: 20"
  echo "      LIMIT_CONFIG_TYPE: functional"
  echo "      FTR_CONFIGS_DEPS: \"\""
  echo "      FTR_CONFIGS_RETRY_COUNT: 0"
  echo "      FTR_CONFIG_PATTERNS: \"$testConfigs\""
done
echo "  - wait: ~"
echo "    continue_on_failure: true"
echo "  - command: .buildkite/scripts/lifecycle/post_build.sh"
echo "    label: Post-Build"
echo "    agents:"
echo "      queue: kibana-default"
