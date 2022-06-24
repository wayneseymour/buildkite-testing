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

github_owner="${ESTF_GITHUB_OWNER:-$(buildkite-agent meta-data get "estf-github-owner" --default 'elastic')}"
github_branch="${ESTF_GITHUB_BRANCH:-$(buildkite-agent meta-data get "estf-github-branch" --default '')}"
github_pr_num="${ESTF_GITHUB_PR_NUM:-$(buildkite-agent meta-data get "estf-github-pr-number" --default '')}"
cloud_version="${ESTF_CLOUD_VERSION:-$(buildkite-agent meta-data get "estf-cloud-version" --default '')}"
num_executions="$(buildkite-agent meta-data get "estf-num-executions" --default '1')"
test_configs="$(buildkite-agent meta-data get "estf-test-configs" --default '')"
basic_ci_groups="$(buildkite-agent meta-data get "estf-basic-ci-groups" --default '')"
xpack_ci_groups="$(buildkite-agent meta-data get "estf-xpack-ci-groups" --default '')"

if [[ "$github_owner" != "elastic" ]] &&
   [[ -z "$github_branch" ]] ||
   [[ -z "$github_pr_num" ]] ||
   [[ -z "$cloud_version" ]]; then
  echo "ESTF_GITHUB_BRANCH or ESTF_GITHUB_PR_NUM must be set"
  echo "ESTF_CLOUD_VERSION must be set"
  false
fi

if [[ $(is_version_ge "$cloud_version" "8.3") == 1 ]] &&
   [[ -z $test_configs ]]; then
  echo "ESTF_TEST_CONFIGS must be set"
  false
else
  if [[ -z "$test_configs" ]] &&
     [[ -z "$basic_ci_groups" ]] &&
     [[ -z "$xpack_ci_groups" ]]; then
    echo "Basic CI Group, Xpack CI Group or Xpack Extended Config must be set"
    false
  fi
fi

TEST_TYPE=""
CI_GROUP=""
if [[ $(is_version_ge "$cloud_version" "8.3") == 0 ]]; then
  TEST_TYPE="xpackext"
  if [[ ! -z $basic_ci_groups ]]; then
    TEST_TYPE="basic"
    CI_GROUP=$basic_ci_groups
  elif [[ ! -z $xpack_ci_groups ]]; then
    TEST_TYPE="xpack"
    CI_GROUP=$xpack_ci_groups
  fi
fi

if [[ $num_executions -gt $LIMIT_NUM_EXECUTIONS ]]; then
  echo "Number of executions is limted to $LIMIT_NUM_EXECUTIONS"
  false
fi

MAX_GROUP=$(( $num_executions / 5 ))
REPEAT_TESTS=5
if [[ $MAX_GROUP == 0 ]]; then
  MAX_GROUP=1
  REPEAT_TESTS=0
fi

if [[ ! -z $test_configs ]]; then
  config_arr=($test_configs)
  if [[ ${#config_arr[@]} -gt $LIMIT_NUM_CONFIGS ]]; then
    echo "Number of configurations is limted to $LIMIT_NUM_CONFIGS"
    false
  fi
  prefix1="test/"
  prefix2="x-pack/test/"
  for config in "${config_arr[@]}"; do
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
  echo "    label: \"Pick Test Groups $i Duplicate - Repeat $REPEAT_TESTS\""
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
  echo "      FTR_CONFIG_PATTERNS: \"$test_configs\""
done
echo "  - wait: ~"
echo "    continue_on_failure: true"
echo "  - command: .buildkite/scripts/lifecycle/post_build.sh"
echo "    label: Post-Build"
echo "    agents:"
echo "      queue: kibana-default"
