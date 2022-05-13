#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for cloud kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -eu

source .buildkite/scripts/common/util.sh

if [[ $(is_version_ge "$ESTF_CLOUD_VERSION" "8.3") == 1 ]]; then
  if [[ -z "$FTR_CONFIGS" ]]; then
    buildkite-agent artifact download ftr_run_order.json .
    ftrConfigGroupsCount=$(jq -r '.count' ftr_run_order.json)
  else
    ftrConfigGroupsCount=1
  fi
else
  # Test types
  testTypes="basic xpack"

  # CI groups
  declare -A testGroups
  testGroups["basic"]="$(seq -s ' ' 1 12)"
  testGroups["xpack"]="2 4 7 8 9 10 12 13 15 19 22 25 26 28 31"

  # Run at a time
  declare -A runGroups
  validRunGroups="$(seq -s ' ' 1 3)"
  runGroups["basic"]=3
  runGroups["xpack"]=3

  # Allows input configuration: TEST_TYPE, CI_GROUP, RUN_GROUP
  if [[ ! -z "${CI_GROUP:-}" ]] && [[ -z "${TEST_TYPE:-}" ]]; then
    echo "CI_GROUP needs TEST_TYPE to be set, one of: ${testTypes// /,}"
    false
  fi

  if [[ ! -z "${RUN_GROUP:-}" ]] && [[ -z "${TEST_TYPE:-}" ]]; then
    echo "RUN_GROUP needs TEST_TYPE to be set, one of: ${testTypes// /,}"
    false
  fi

  if [[ ! -z "${TEST_TYPE:-}" ]]; then
    echo "TEST_TYPE is set to: $TEST_TYPE"
    case " $testTypes " in (*" $TEST_TYPE "*) :;; (*) echo "Valid values: ${testTypes// /, }"; false;; esac
    testTypes=$TEST_TYPE
  fi

  if [[ ! -z "${CI_GROUP:-}" ]]; then
    echo "CI_GROUP is set to: $CI_GROUP"
    case " ${testGroups[$TEST_TYPE]} " in (*" $CI_GROUP "*) :;; (*) echo "Valid values: ${testGroups[$TEST_TYPE]}"; false;; esac
    testGroups[${TEST_TYPE}]=${CI_GROUP}
  fi

  if [[ ! -z "${RUN_GROUP:-}" ]]; then
    echo "RUN_GROUP is set to: $RUN_GROUP"
    case " $validRunGroups " in (*" $RUN_GROUP "*) :;; (*) echo "Valid values: ${validRunGroups// /, }"; false;; esac
    runGroups[${TEST_TYPE}]=${RUN_GROUP}
  fi
fi

get_buildkite_group() {
  echo "  - group: \"${metaId} cloud kibana group\""
  echo "    key: \"cktg_${metaId}\""
  echo "    steps:"
  echo "      - label: \"${metaId} create cloud deployment\""
  echo "        key: \"create_cloud_deployment_${metaId}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/create_cloud_deployment.sh"
  echo "        env:"
  echo "          ESTF_META_ID: ${metaId}"
  echo "        agents:"
  echo "          queue: n2-4"
  echo "      - label: \"${metaId} run kibana functional tests\""
  echo "        key: \"run_kibana_tests_${metaId}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/cloud_run_kibana_tests.sh"
  echo "        env:"
  echo "          ESTF_META_ID: ${metaId}"
  echo "          ESTF_KIBANA_TEST_TYPE: ${testType:-}"
  echo "          ESTF_KIBANA_INCLUDE_TAG: ${includeTag:-}"
  echo "          ESTF_FTR_CONFIGS: \"${ftrConfigs:-}\""
  echo "          ESTF_FTR_CONFIG_GROUP: ${ftrConfigGroup:-}"
  echo "        agents:"
  echo "          queue: n2-4"
  echo "        depends_on: \"create_cloud_deployment_${metaId}\""
  echo "      - wait: ~"
  echo "        continue_on_failure: true"
  echo "      - label: \"${metaId} annotate junit\""
  echo "        key: \"annotate_junit_${metaId}\""
  echo "        plugins:"
  echo "          - junit-annotate#v2.0.2:"
  echo "              artifacts: target/junit/**/*"
  echo "        agents:"
  echo "          queue: n2-4"
  echo "      - label: \"${metaId} delete cloud deployment\""
  echo "        key: \"delete_cloud_deployment_${metaId}\""
  echo "        command: .buildkite/scripts/steps/estf/cloud/shutdown_cloud_deployment.sh"
  echo "        env:"
  echo "          ESTF_META_ID: ${metaId}"
  echo "        agents:"
  echo "          queue: n2-4"
}

if [[ ! -z "${ftrConfigGroupsCount:-}" ]]; then
  for groupInd in $(seq -s ' ' 0 $((ftrConfigGroupsCount-1)));
  do
    metaId="ftr_configs_${groupInd}"
    ftrConfigGroup=$groupInd
    if [[ -z "$FTR_CONFIGS" ]]; then
      ftrConfigs=$(jq -r ".groups[$groupInd].names | .[]" ftr_run_order.json)
    else
      ftrConfigs="${FTR_CONFIGS}"
    fi
    get_buildkite_group
  done
else
  for testType in $testTypes;
  do
    ciGroupsArray=(${testGroups[$testType]// / })
    runGroup=${runGroups[$testType]}
    arrayLength=${#ciGroupsArray[@]}
    if [[ $arrayLength -lt $runGroup ]]; then
      runGroup=$arrayLength
    fi
    for ((i=0; i<${#ciGroupsArray[*]}; i=i+$runGroup));
    do
      ind1=$((i))
      ind2=$((i+1))
      ind3=$((i+2))
      metaId="${testType}-${ciGroupsArray[$ind1]}"
      includeTag="--include-tag ciGroup${ciGroupsArray[$ind1]}";
      case $runGroup in
        1)
          ;;
        2)
          if [[ $ind2 -lt $arrayLength ]]; then
            metaId+="_${ciGroupsArray[$ind2]}"
            includeTag+=" --include-tag ciGroup${ciGroupsArray[$ind2]}";
          fi
          ;;
        3)
          if [[ $ind2 -lt $arrayLength ]]; then
            metaId+="_${ciGroupsArray[$ind2]}"
            includeTag+=" --include-tag ciGroup${ciGroupsArray[$ind2]}";
          fi
          if [[ $ind3 -lt $arrayLength ]]; then
            metaId+="_${ciGroupsArray[$ind3]}"
            includeTag+=" --include-tag ciGroup${ciGroupsArray[$ind3]}";
          fi
          ;;
        *)
          echo "Valid run up to ${validRunGroups// /, } at a time"
          false;
          ;;
      esac
      get_buildkite_group
    done
  done
fi
