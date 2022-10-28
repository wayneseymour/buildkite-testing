#!/usr/bin/env bash

source .buildkite/scripts/common/util.sh

run_ftr_cloud_configs() {
  excludeTests="$1"

  export TEST_CLOUD=1
  export JOB=kibana-$ESTF_META_ID

  echo "--- in run_ftr_cloud_configs"

  cloudVersion=$(get_cloud_version)

  repeat_tests=$(get_repeat_tests)
  repeats=$(seq -s ' ' 1 1)
  if [[ $repeat_tests > 0 ]]; then
    repeats=$(seq -s ' ' 1 $repeat_tests)
  fi

  export ES_SECURITY_ENABLED=true

  FAILED_CONFIGS_KEY="${BUILDKITE_STEP_ID}${ESTF_FTR_CONFIG_GROUP:-0}"

  # a FTR failure will result in the script returning an exit code of 10
  exitCode=0

  configs="${ESTF_FTR_CONFIGS:-}"

  echo_debug "Configs: $configs"

  # The first retry should only run the configs that failed in the previous attempt
  # Any subsequent retries, which would generally only happen by someone clicking the button in the UI, will run everything
  if [[ "${BUILDKITE_RETRY_COUNT:-0}" == "1" ]]; then
    configs=$(buildkite-agent meta-data get "$FAILED_CONFIGS_KEY" --default '')
    if [[ "$configs" ]]; then
      echo "--- Retrying only failed configs"
      echo "$configs"
    fi
  fi

  if [[ "$configs" == "" ]]; then
    echo "--- downloading ftr test run order"
    buildkite-agent artifact download ftr_run_order.json . --step "$BUILDKITE_JOB_ID"
    configs=$(jq -r '.groups[env.ESTF_FTR_CONFIG_GROUP | tonumber].names | .[]' ftr_run_order.json)
  fi

  failedConfigs=""
  results=()

  for run in $repeats; do
    for config in ${configs//,/ }; do
      if [[ ! -f "$config" ]]; then
        echo_warning "Invalid configuration: $config"
        continue;
      fi

      echo "--- $ node scripts/functional_test_runner --config $config"
      start=$(date +%s)

      # prevent non-zero exit code from breaking the loop
      set +e;
      eval node scripts/functional_test_runner \
                --es-version "$cloudVersion" \
                --exclude-tag skipCloud \
                --exclude-tag skipCloudFailedTest \
                --config="$config" \
                " $excludeTests"
      lastCode=$?
      set -e;

      timeSec=$(($(date +%s)-start))
      if [[ $timeSec -gt 60 ]]; then
        min=$((timeSec/60))
        sec=$((timeSec-(min*60)))
        duration="${min}m ${sec}s"
      else
        duration="${timeSec}s"
      fi

      results+=("- $config
        duration: ${duration}
        result: ${lastCode}")

      if [ $lastCode -ne 0 ]; then
        exitCode=10
        echo "FTR exited with code $lastCode"
        echo "^^^ +++"

        if [[ "$failedConfigs" ]]; then
          failedConfigs="${failedConfigs}"$'\n'"$config"
        else
          failedConfigs="$config"
        fi
      fi
    done
    if [[ $exitCode == 10 ]] && [[ $repeat_tests > 0 ]]; then
      echo "There were failures, stopping test loop, run $run of $repeat_tests"
      break
    fi
  done

  if [[ "$failedConfigs" ]]; then
    buildkite-agent meta-data set "$FAILED_CONFIGS_KEY" "$failedConfigs"
  fi

  echo "--- FTR configs complete"
  printf "%s\n" "${results[@]}"
  echo ""

  return $exitCode
}

run_ftr_cloud_ci_groups() {
  excludeTests="$1"

  export TEST_CLOUD=1
  export JOB=kibana-$ESTF_META_ID

  cloudVersion=$(get_cloud_version)

  repeat_tests=$(get_repeat_tests)
  repeats=$(seq -s ' ' 1 1)
  if [[ $repeat_tests > 0 ]]; then
    repeats=$(seq -s ' ' 1 $repeat_tests)
  fi

  results=()
  exitCode=0
  for run in $repeats; do
    # Run basic group
    if [[ "$ESTF_KIBANA_TEST_TYPE" == "basic" ]]; then
        export ES_SECURITY_ENABLED=true
        echo "--- Basic tests run against ESS"
        set +e;
        eval node scripts/functional_test_runner \
                --config "test/functional/config.js" \
                --es-version "$cloudVersion" \
                --exclude-tag skipCloud \
                --exclude-tag skipCloudFailedTest \
                " $ESTF_KIBANA_INCLUDE_TAG" \
                " $excludeTests"
        lastCode=$?
        set -e;
        results+=("result: ${lastCode}")
        if [ $lastCode -ne 0 ]; then
          exitCode=10
          echo "FTR exited with code $lastCode"
          echo "^^^ +++"
        fi
    fi

    # Run xpack group
    if [[ "$ESTF_KIBANA_TEST_TYPE" == "xpack" ]]; then
        echo "--- Xpack tests run against ESS"
        set +e;
        eval node scripts/functional_test_runner \
                --config "x-pack/test/functional/config.js" \
                --es-version "$cloudVersion" \
                --exclude-tag skipCloud \
                --exclude-tag skipCloudFailedTest \
                " $ESTF_KIBANA_INCLUDE_TAG" \
                " $excludeTests"
        lastCode=$?
        set -e;
        results+=("result: ${lastCode}")
        if [ $lastCode -ne 0 ]; then
          exitCode=10
          echo "FTR exited with code $lastCode"
          echo "^^^ +++"
        fi
    fi
    if [[ $exitCode == 10 ]] && [[ $repeat_tests > 0 ]]; then
      echo "There were failures, stopping test loop, run $run of $repeat_tests"
      break
    fi
  done

  echo "--- FTR configs complete"
  printf "%s\n" "${results[@]}"
  echo ""

  return $exitCode

}

run_ftr_cloud_visual_tests() {
  export TEST_CLOUD=1
  export JOB=kibana-$ESTF_META_ID

  cloudVersion=$(get_cloud_version)

  repeat_tests=$(get_repeat_tests)
  repeats=$(seq -s ' ' 1 1)
  if [[ $repeat_tests > 0 ]]; then
    repeats=$(seq -s ' ' 1 $repeat_tests)
  fi

  results=()
  exitCode=0
  for run in $repeats; do
    # Run basic group
    if [[ "$ESTF_KIBANA_TEST_TYPE" == "basic" ]]; then
        export ES_SECURITY_ENABLED=true
        echo "--- Visual basic tests run against ESS"
        set +e;
        yarn run percy exec -- -t 700 -- \
          node scripts/functional_test_runner --config test/visual_regression/config.ts
        lastCode=$?
        set -e;
        results+=("result: ${lastCode}")
        if [ $lastCode -ne 0 ]; then
          exitCode=10
          echo "FTR exited with code $lastCode"
          echo "^^^ +++"
        fi
    fi

    # Run xpack group
    if [[ "$ESTF_KIBANA_TEST_TYPE" == "xpack" ]]; then
        echo "--- Visual xpack tests run against ESS"
        set +e;
        yarn run percy exec -- -t 700 -- \
          node scripts/functional_test_runner --config x-pack/test/visual_regression/config.ts
        lastCode=$?
        set -e;
        results+=("result: ${lastCode}")
        if [ $lastCode -ne 0 ]; then
          exitCode=10
          echo "FTR exited with code $lastCode"
          echo "^^^ +++"
        fi
    fi
    if [[ $exitCode == 10 ]] && [[ $repeat_tests > 0 ]]; then
      echo "There were failures, stopping test loop, run $run of $repeat_tests"
      break
    fi
  done

  echo "--- FTR configs complete"
  printf "%s\n" "${results[@]}"
  echo ""

  return $exitCode

}

run_ftr_kibana_os_tests() {
  smokeTests="$1"

  export JOB=kibana-$ESTF_META_ID

  echo "--- in run_ftr_kibana_os_tests"

  repeat_tests=$(get_repeat_tests)
  repeats=$(seq -s ' ' 1 1)
  if [[ $repeat_tests > 0 ]]; then
    repeats=$(seq -s ' ' 1 $repeat_tests)
  fi

  export ES_SECURITY_ENABLED=true

  FAILED_CONFIGS_KEY="${BUILDKITE_STEP_ID}${ESTF_FTR_CONFIG_GROUP:-0}"

  # a FTR failure will result in the script returning an exit code of 10
  exitCode=0

  configs="$smokeTests"

  echo_debug "Configs: $configs"

  # The first retry should only run the configs that failed in the previous attempt
  # Any subsequent retries, which would generally only happen by someone clicking the button in the UI, will run everything
  if [[ "${BUILDKITE_RETRY_COUNT:-0}" == "1" ]]; then
    configs=$(buildkite-agent meta-data get "$FAILED_CONFIGS_KEY" --default '')
    if [[ "$configs" ]]; then
      echo "--- Retrying only failed configs"
      echo "$configs"
    fi
  fi

  failedConfigs=""
  results=()

  export NODE_TLS_REJECT_UNAUTHORIZED=0
  nodeOpts=" "
  if [ ! -z $NODE_TLS_REJECT_UNAUTHORIZED ] && [[ $NODE_TLS_REJECT_UNAUTHORIZED -eq 0 ]]; then
    nodeOpts="--no-warnings "
  fi

  for run in $repeats; do
    for config in ${configs//,/ }; do
      if [[ ! -f "$config" ]]; then
        echo_warning "Invalid configuration: $config"
        continue;
      fi

      echo "--- $ node scripts/functional_test_runner --config $config"
      start=$(date +%s)

      # prevent non-zero exit code from breaking the loop
      set +e;
      eval node $nodeOpts scripts/functional_test_runner \
                --config="$config"
      lastCode=$?
      set -e;

      timeSec=$(($(date +%s)-start))
      if [[ $timeSec -gt 60 ]]; then
        min=$((timeSec/60))
        sec=$((timeSec-(min*60)))
        duration="${min}m ${sec}s"
      else
        duration="${timeSec}s"
      fi

      results+=("- $config
        duration: ${duration}
        result: ${lastCode}")

      if [ $lastCode -ne 0 ]; then
        exitCode=10
        echo "FTR exited with code $lastCode"
        echo "^^^ +++"

        if [[ "$failedConfigs" ]]; then
          failedConfigs="${failedConfigs}"$'\n'"$config"
        else
          failedConfigs="$config"
        fi
      fi
    done
    if [[ $exitCode == 10 ]] && [[ $repeat_tests > 0 ]]; then
      echo "There were failures, stopping test loop, run $run of $repeat_tests"
      break
    fi
  done

  if [[ "$failedConfigs" ]]; then
    buildkite-agent meta-data set "$FAILED_CONFIGS_KEY" "$failedConfigs"
  fi

  echo "--- FTR configs complete"
  printf "%s\n" "${results[@]}"
  echo ""

  return $exitCode
}
