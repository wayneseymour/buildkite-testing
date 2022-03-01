#!/usr/bin/env bash

set -euo pipefail

echo "Set env variable in this step"

buildkite-agent meta-data set "estf-data-test" "liza"

exit 0