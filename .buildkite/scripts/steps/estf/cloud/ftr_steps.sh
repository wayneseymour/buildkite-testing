#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for cloud kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -eu

buildkite-agent artifact download ftr_run_order.json .
group_count=$(jq -r '.count' ftr_run_order.json)

echo "steps:"
for i in $(seq -s ' ' 0 $((group_count-1))); do
  configs=$(jq -r ".groups[$i].names | .[]" ftr_run_order.json)
  echo "  - label: \"Test $i\""
  echo "    command: echo \"$configs\""
  echo "    agents:"
  echo "      queue: kibana-default"
done
