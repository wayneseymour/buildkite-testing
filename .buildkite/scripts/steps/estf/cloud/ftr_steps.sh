#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for cloud kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -eu

buildkite-agent artifact download ftr_run_order.json .
group_count=$(jq -r '.count' ftr_run_order.json)

echo "  - command: echo testing"
echo "    parallelism: $group_count"
echo "    agents:"
echo "      queue: kibana-default"
