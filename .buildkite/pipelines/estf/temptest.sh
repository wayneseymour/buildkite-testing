#!/bin/bash

set -eu

source .buildkite/scripts/common/util.sh

cloudVersion=$(get_cloud_version)
excludedTests=$(get_excluded_tests)

echo $cloudVersion
echo $excludedTests

