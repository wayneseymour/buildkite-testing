#!/usr/bin/env bash

NC='\033[0m' # No Color
WHITE='\033[1;37m'
BLACK='\033[0;30m'
BLUE='\033[0;34m'
LIGHT_BLUE='\033[1;34m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m'
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
RED='\033[0;31m'
LIGHT_RED='\033[1;31m'
PURPLE='\033[0;35m'
LIGHT_PURPLE='\033[1;35m'
BROWN='\033[0;33m'
YELLOW='\033[1;33m'
GRAY='\033[0;30m'
LIGHT_GRAY='\033[0;37m'

echo_error_exit() {
  echo -e ${RED}" $1"${NC} >&2
  exit 1
}

echo_error() {
  echo -e ${RED}" $1"${NC} >&2
}

echo_warning() {
  echo -e ${YELLOW}":warning: $1"${NC}
}

echo_info() {
  echo -e ${LIGHT_BLUE}"$1"${NC}
}

echo_debug() {
  echo -e ${GRAY}"$1"${NC}
}

format_version() {
  version=${1%"-SNAPSHOT"}
  printf "%03d%03d%03d%03d" $(echo "$version" | tr '.' ' ')
}

is_version_ge() {
  if [ $(format_version $1) -ge $(format_version $2) ]; then
    echo 1
  else
   echo 0
  fi
}

get_branch_from_version() {
  branch=""
  cloudVersion=$(get_cloud_version)
  if [[ "${cloudVersion:-}" =~ [0-9]+\.[0-9]+ ]]; then
    branch=${BASH_REMATCH[0]}
  fi
  echo $branch
}

get_cloud_version() {
  metaData=$(buildkite-agent meta-data get "estf-cloud-version" --default '')
  value="${ESTF_CLOUD_VERSION:-$metaData}"
  echo $value
}

get_github_owner() {
  metaData=$(buildkite-agent meta-data get "estf-github-owner" --default 'elastic')
  value="${ESTF_GITHUB_OWNER:-$metaData}"
  echo $value
}

get_github_repo() {
  repo=${1:-kibana}
  metaData=$(buildkite-agent meta-data get "estf-github-repo" --default $repo)
  value="${ESTF_GITHUB_REPO:-$metaData}"
  echo $value
}

get_github_ref_repo() {
  defaultValue="/var/lib/gitmirrors/https---github-com-elastic-kibana-git"
  value="${ESTF_KIBANA_REF_REPO:-$defaultValue}"
  echo $value
}

get_main_version_kibana() {
  file="https://raw.githubusercontent.com/elastic/kibana/main/package.json"
  curl -s $file | grep \"version\": | awk -F\" '/"version":/ {print substr($4,1,3)}'
}

get_version_from_message() {
  main_ver=$(get_main_version_kibana)
  re='[0-9]+\.[0-9]+';
  if [[ "$BUILDKITE_MESSAGE" =~ $re ]]; then
    extract_ver="${BASH_REMATCH[0]}";
    if [[ "$extract_ver" == "$main_ver" ]]; then
      echo "main"
    else
      echo "$extract_ver"
    fi
  fi
}

get_github_branch() {
  getFromMsg=${1:-false}
  metaData=$(buildkite-agent meta-data get "estf-github-branch" --default '')
  value="${ESTF_GITHUB_BRANCH:-$metaData}"
  if [[ -z $value ]] && [[ $getFromMsg == "true" ]]; then
    echo $(get_version_from_message)
  fi
  echo $value
}

get_github_pr_num() {
  metaData=$(buildkite-agent meta-data get "estf-github-pr-number" --default '')
  value="${ESTF_GITHUB_PR_NUM:-$metaData}"
  value="${value##*/}"
  echo ${value#"pr-"}
}

get_num_executions() {
  metaData="$(buildkite-agent meta-data get "estf-num-executions" --default '1')"
  echo $metaData
}

get_test_configs() {
  metaData="$(buildkite-agent meta-data get "estf-test-configs" --default '')"
  echo $metaData
}

get_config_seq() {
  metaData="$(buildkite-agent meta-data get "estf-config-seq" --default 'false')"
  echo $metaData
}

get_basic_ci_groups() {
  metaData="$(buildkite-agent meta-data get "estf-basic-ci-groups" --default '')"
  echo $metaData
}

get_xpack_ci_groups() {
  metaData="$(buildkite-agent meta-data get "estf-xpack-ci-groups" --default '')"
  echo $metaData
}

get_repeat_tests() {
  metaData=$(buildkite-agent meta-data get "estf-repeat-tests" --default '0')
  echo $metaData
}

is_pipeline_cloud_kibana_func_tests() {
  substr="estf-cloud-kibana-functional-tests"
  if [[ $BUILDKITE_BUILD_URL == *"$substr"* ]]; then
    echo 1
  elif [[ $BUILDKITE_BUILD_URL == *"liza-job"* ]]; then
    echo 1
  else
    echo 0
  fi
}

get_excluded_tests() {
  ftrExcludes=""
  if [[ $(is_pipeline_cloud_kibana_func_tests) == "1" ]]; then
    testingDir=".buildkite/scripts/steps/estf/kibana/testing"
    excludeFile="$testingDir/$(get_branch_from_version)/exclude"
    if [[ -f "$excludeFile" ]]; then
      while read line; do
        if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
          continue
        fi
        ftrExcludes+=" --exclude $line"
      done < "$excludeFile"
    fi
  fi
  echo $ftrExcludes
}

get_smoke_tests() {
  ftrSmokeTests=""
  testingDir=".buildkite/scripts/steps/estf/kibana/testing"
  smokeTestFile="$testingDir/$(get_branch_from_version)/smoke"
  if [[ -f "$smokeTestFile" ]]; then
    while read line; do
      if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
        continue
      fi
      splitStr=(${line//,/ })
      ftrSmokeTests+=" --config ${splitStr[0]}"
      if [[ ! -z ${splitStr[1]} ]]; then
        ftrSmokeTests+=" --include ${splitStr[1]}"
      fi
      if [[ ! -z ${splitStr[2]} ]]; then
        ftrSmokeTests+=" --include-tag ${splitStr[1]}"
      fi
    done < "$smokeTestFile"
  fi
  echo $ftrSmokeTests
}

# -- From github.com/elastic/kibana repo .buildkite/scripts/common/util.sh

# docker_run can be used in place of `docker run`
# it automatically passes along all of Buildkite's tracked environment variables, and mounts the buildkite-agent in the running container
docker_run() {
  args=()

  if [[ -n "${BUILDKITE_ENV_FILE:-}" ]] ; then
    # Read in the env file and convert to --env params for docker
    # This is because --env-file doesn't support newlines or quotes per https://docs.docker.com/compose/env-file/#syntax-rules
    while read -r var; do
      args+=( --env "${var%%=*}" )
    done < "$BUILDKITE_ENV_FILE"
  fi

  BUILDKITE_AGENT_BINARY_PATH=$(command -v buildkite-agent)
  args+=(
    "--env" "BUILDKITE_JOB_ID"
    "--env" "BUILDKITE_BUILD_ID"
    "--env" "BUILDKITE_AGENT_ACCESS_TOKEN"
    "--volume" "$BUILDKITE_AGENT_BINARY_PATH:/usr/bin/buildkite-agent"
  )

  docker run "${args[@]}" "$@"
}

# -- From github.com/elastic/kibana repo .buildkite/scripts/common/util.sh
is_test_execution_step() {
  buildkite-agent meta-data set "${BUILDKITE_JOB_ID}_is_test_execution_step" 'true'
}

# -- From github.com/elastic/kibana repo .buildkite/scripts/common/util.sh
retry() {
  local retries=$1; shift
  local delay=$1; shift
  local attempts=1

  until "$@"; do
    retry_exit_status=$?
    echo "Exited with $retry_exit_status" >&2
    if (( retries == "0" )); then
      return $retry_exit_status
    elif (( attempts == retries )); then
      echo "Failed $attempts retries" >&2
      return $retry_exit_status
    else
      echo "Retrying $((retries - attempts)) more times..." >&2
      attempts=$((attempts + 1))
      sleep "$delay"
    fi
  done
}
