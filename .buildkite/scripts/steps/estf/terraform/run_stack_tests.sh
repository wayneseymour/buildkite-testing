#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run stack tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/steps/estf/ansible/ansible_setup.sh

echo "--- Run stack tests"
./playbooks/stack_testing/ci/buildkite_stack_testing.sh
