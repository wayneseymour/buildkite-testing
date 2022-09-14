#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for cloud kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/common/util.sh

cloudVersion=$(get_cloud_version)
if ([[ $(is_version_ge "$cloudVersion" "8.3") == 1 ]] || [[ "${TEST_TYPE:-}" == "xpackext" ]]) &&
   [[ -z "${FTR_CONFIGS:-}" ]]; then
  buildkite-agent artifact download ftr_run_order.json . --step "$BUILDKITE_JOB_ID"
  ftrConfigGroupsCount=$(jq -r '.count' ftr_run_order.json)
elif [[ "${TEST_TYPE:-}" == "xpackext" ]] && [[ -z "${FTR_CONFIGS:-}" ]] && [[ -z "${FTR_CONFIG_PATTERNS:-}" ]]; then
  echo_error_exit "FTR_CONFIGS or FTR_CONFIG_PATTERNS must be set"
elif [[ ! -z "${FTR_CONFIGS:-}" ]]; then
  ftrConfigGroupsCount=1
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
  runGroups["basic"]=2
  runGroups["xpack"]=2

  # Allows input configuration: TEST_TYPE, CI_GROUP, RUN_GROUP
  if [[ ! -z "${CI_GROUP:-}" ]] && [[ -z "${TEST_TYPE:-}" ]]; then
    echo_error_exit "CI_GROUP needs TEST_TYPE to be set, one of: ${testTypes// /,}"
  fi

  if [[ ! -z "${RUN_GROUP:-}" ]] && [[ -z "${TEST_TYPE:-}" ]]; then
    echo_error_exit "RUN_GROUP needs TEST_TYPE to be set, one of: ${testTypes// /,}"
  fi

  if [[ ! -z "${TEST_TYPE:-}" ]]; then
    case " $testTypes " in (*" $TEST_TYPE "*) :;; (*) echo_error_exit "Valid values: ${testTypes// /, }";; esac
    testTypes=$TEST_TYPE
  fi

  if [[ ! -z "${CI_GROUP:-}" ]]; then
    case " ${testGroups[$TEST_TYPE]} " in (*" $CI_GROUP "*) :;; (*) echo_error_exit "Valid values: ${testGroups[$TEST_TYPE]}";; esac
    testGroups[${TEST_TYPE}]=${CI_GROUP}
  fi

  if [[ ! -z "${RUN_GROUP:-}" ]]; then
    case " $validRunGroups " in (*" $RUN_GROUP "*) :;; (*) echo_error_exit "Valid values: ${validRunGroups// /, }";; esac
    runGroups[${TEST_TYPE}]=${RUN_GROUP}
  fi
fi

get_buildkite_group() {
  echo "  - label: \"${metaId} ess kibana testing\""
  echo "    key: \"ess_kibana_testing_${metaId}\""
  echo "    command: .buildkite/scripts/steps/estf/ess/ess_kibana_testing.sh"
  if [[ "${ESTF_RETRY_TEST:=-}" == "true" ]]; then
  echo "    retry:"
  echo "      automatic:"
  echo "        - exit_status: \"*\""
  echo "          limit: 1"
  fi
  echo "    env:"
  echo "      ESTF_META_ID: ${metaId}"
  echo "      ESTF_PLAN_SETTINGS: \"${estfPlanSettings}\""
  echo "      ESTF_KIBANA_TEST_TYPE: ${testType:-}"
  echo "      ESTF_KIBANA_INCLUDE_TAG: ${includeTag:-}"
  echo "      ESTF_FTR_CONFIGS: \"${ftrConfigs:-}\""
  echo "      ESTF_FTR_CONFIG_GROUP: ${ftrConfigGroup:-}"
  echo "      ESTF_RETRY_TEST: ${ESTF_RETRY_TEST:-}"
  echo "    agents:"
  echo "      queue: n2-4"
}

if [[ ! -z "${ftrConfigGroupsCount:-}" ]]; then
  defaulSettings="true"
  reportSettings="false"
  securitySolnSettings="false"
  if [[ ! -z "${ESTF_PLAN_SETTINGS:-}" ]]; then
    defaultSettings="false"
  fi
  for groupInd in $(seq -s ' ' 0 $((ftrConfigGroupsCount-1)));
  do
    testType="${TEST_TYPE:-all}"
    metaId="${testType}_${groupInd}_$BUILDKITE_JOB_ID"
    ftrConfigGroup=$groupInd
    estfPlanSettings="${ESTF_PLAN_SETTINGS:-kibana_default.json}"
    if [[ -z "${FTR_CONFIGS:-}" ]]; then
      ftrConfigs=$(jq -r ".groups[$groupInd].names | .[]" ftr_run_order.json)
    else
      ftrConfigs="${FTR_CONFIGS}"
    fi
    if [[ "$defaulSettings" == "true" ]]; then
      if [[ "$reportSettings" == "false" ]] && [[ "$ftrConfigs" == *"reporting"* ]]; then
        estfPlanSettings+=" kibana_reporting.json"
        reportSettings="true"
      fi
      if [[ "$securitySolnSettings" == "false" ]] && [[ "$ftrConfigs" == *"security_solution_endpoint"* ]]; then
        estfPlanSettings+=" kibana_security_solution_endpoint.json"
        securitySolnSettings="true"
      fi
    fi
    get_buildkite_group
  done
else
  for testType in $testTypes;
  do
    ciGroupsArray=(${testGroups[$testType]// / })
    runGroup=${runGroups[$testType]}
    arrayLength=${#ciGroupsArray[@]}
    estfPlanSettings="${ESTF_PLAN_SETTINGS:-kibana_default.json}"
    if [[ $arrayLength -lt $runGroup ]]; then
      runGroup=$arrayLength
    fi
    for ((i=0; i<${#ciGroupsArray[*]}; i=i+$runGroup));
    do
      ind1=$((i))
      ind2=$((i+1))
      ind3=$((i+2))
      metaId="${testType}-${ciGroupsArray[$ind1]}_$BUILDKITE_JOB_ID"
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
          echo_error_exit "Valid run up to ${validRunGroups// /, } at a time"
          ;;
      esac
      get_buildkite_group
    done
  done
fi
