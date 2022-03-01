#!/usr/bin/env bash

set -euo pipefail

echo "Does this env variable exists? "
echo $(buildkite-agent meta-data get "estf-data-test")
echo "end-- "