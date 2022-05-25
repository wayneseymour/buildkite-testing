#!/usr/bin/env bash

source .buildkite/scripts/common/util.sh

run_ftr_cloud_configs() {
  export TEST_CLOUD=1
  export JOB=kibana-$ESTF_META_ID

  if [[ "$ESTF_KIBANA_TEST_TYPE" == "basic" ]]; then
    export ES_SECURITY_ENABLED=true
  fi

  FAILED_CONFIGS_KEY="${BUILDKITE_STEP_ID}${ESTF_FTR_CONFIG_GROUP:-0}"

  # a FTR failure will result in the script returning an exit code of 10
  exitCode=0

  configs="${ESTF_FTR_CONFIGS:-}"

  # The first retry should only run the configs that failed in the previous attempt
  # Any subsequent retries, which would generally only happen by someone clicking the button in the UI, will run everything
  if [[ ! "$configs" && "${BUILDKITE_RETRY_COUNT:-0}" == "1" ]]; then
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

  for config in $configs; do
    if [[ ! -f "$config" ]]; then
      echo_warning "Invalid configuration: $config"
      continue;
    fi

    echo "--- $ node scripts/functional_test_runner --config $config"
    start=$(date +%s)

    # prevent non-zero exit code from breaking the loop
    set +e;
    node scripts/functional_test_runner \
              --es-version "$ESTF_CLOUD_VERSION" \
              --exclude-tag skipCloud \
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

  if [[ "$failedConfigs" ]]; then
    buildkite-agent meta-data set "$FAILED_CONFIGS_KEY" "$failedConfigs"
  fi

  echo "--- FTR configs complete"
  printf "%s\n" "${results[@]}"
  echo ""

  exit $exitCode
}

run_ftr_cloud_ci_groups() {
  export TEST_CLOUD=1
  export JOB=kibana-$ESTF_META_ID

  # Run basic group
  if [[ "$ESTF_KIBANA_TEST_TYPE" == "basic" ]]; then
      export ES_SECURITY_ENABLED=true
      echo "--- Basic tests run against ESS"
      eval node scripts/functional_test_runner \
              --es-version "$ESTF_CLOUD_VERSION" \
              --exclude-tag skipCloud " $ESTF_KIBANA_INCLUDE_TAG"
  fi

  # Run xpack group
  if [[ "$ESTF_KIBANA_TEST_TYPE" == "xpack" ]]; then
      cd x-pack
      echo "--- Xpack tests run against ESS"
      eval node scripts/functional_test_runner \
              --es-version "$ESTF_CLOUD_VERSION" \
              --exclude-tag skipCloud " $ESTF_KIBANA_INCLUDE_TAG"
  fi
}
