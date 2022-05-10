#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for cloud kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -eu

buildkite-agent pipeline upload base.yml