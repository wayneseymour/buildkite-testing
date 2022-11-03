#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for platform testing
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

echo "  - command: .buildkite/scripts/lifecycle/pre_build.sh"
echo "    label: Pre-Build"
echo "    timeout_in_minutes: 10"
echo "    agents:"
echo "      queue: kibana-default"
echo "  - wait"

osFile=".buildkite/scripts/steps/estf/terraform/testing/operating_systems"
while read line; do
  if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
    continue
  fi
  read -a osarray <<< $line
  if [[ "${#osarray[@]}" -ne 3 ]]; then
    continue
  fi
  echo "  - command: .buildkite/scripts/steps/estf/terraform/tf_kibana_os_testing.sh"
  echo "    label: ${osarray[2]}"
  echo "    agents:"
  echo "      queue: n2-4"
  echo "    env:"
  echo "      ESTF_META_ID: tf-kibana-os-${osarray[2]}"
  echo "      ESTF_KIBANA_OS_TEST: true"
  echo "      AIT_PROVIDER: ${osarray[0]}"
  echo "      AIT_USER: buildkite-agent"
  echo "      AIT_IMAGE: ${osarray[1]}/${osarray[2]}"
done < "$osFile"

osFile=".buildkite/scripts/steps/estf/terraform/testing/operating_systems_arm"
while read line; do
  if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
    continue
  fi
  read -a osarray <<< $line
  if [[ "${#osarray[@]}" -ne 3 ]]; then
    continue
  fi
  echo "  - command: .buildkite/scripts/steps/estf/terraform/tf_kibana_os_testing.sh"
  echo "    label: ${osarray[2]}"
  echo "    agents:"
  echo "      queue: n2-4"
  echo "    env:"
  echo "      ESTF_META_ID: tf-kibana-os-${osarray[2]}"
  echo "      ESTF_KIBANA_OS_TEST: true"
  echo "      ES_BUILD_ARCH: arm64"
  echo "      AIT_MACHINE_TYPE: t2a-standard-8"
  echo "      AIT_PROVIDER: ${osarray[0]}"
  echo "      AIT_USER: buildkite-agent"
  echo "      AIT_IMAGE: ${osarray[1]}/${osarray[2]}"
done < "$osFile"

echo "  - wait: ~"
echo "    continue_on_failure: true"
echo "  - command: .buildkite/scripts/lifecycle/post_build.sh"
echo "    label: Post-Build"
echo "    agents:"
echo "      queue: kibana-default"