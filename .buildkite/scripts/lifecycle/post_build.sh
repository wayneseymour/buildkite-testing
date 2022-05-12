#!/usr/bin/env bash

set -euo pipefail

BUILD_SUCCESSFUL=$(node "$(dirname "${0}")/build_status.js")
export BUILD_SUCCESSFUL

node "$(dirname "${0}")/ci_stats_complete.js"
