#!/bin/bash

# ----------------------------------------------------------------------------
# Buildkite dynamic pipeline script for cloud kibana functional tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -eu

buildkite-agent pipeline upload .buildkite/pipelines/estf/base.yml