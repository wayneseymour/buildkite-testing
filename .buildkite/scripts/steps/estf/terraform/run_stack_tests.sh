#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run stack tests
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

echo "--- Run stack tests"

githubOwner="$(get_github_owner)"
githubRepo="$(get_github_repo elastic-stack-testing)"
githubRefRepo="$(get_github_ref_repo)"
githubBranch="$(get_github_branch)"
githubPrNum="$(get_github_pr_num)"
excludeTests="$(get_excluded_tests)"

echo "--- Clone estf repo and chdir"
git clone "https://github.com/$githubOwner/$githubRepo"
cd elastic-stack-testing

echo "--- Checkout elastic-stack-testing"
if [[ ! -z "$githubPrNum" ]]; then
  prefix="pr-"
  num=${githubPrNum#"$prefix"}
  git fetch origin pull/$num/head:pr-$num
  git checkout pr-$num
elif [[ ! -z "$githubBranch" ]]; then
  git checkout -f "$githubBranch"
else
  buildkite-agent meta-data exists "estf-stack-hash-$ESTF_META_ID"
  git checkout -f $(buildkite-agent meta-data get "estf-stack-hash-$ESTF_META_ID")
fi

echo "--- Run ansible playbook"
# TODO: this needs to be fixed from RM
export ES_BUILD_URL=snapshots.elastic.co/${ESTF_BUILD_ID}

export AIT_UUT=$(buildkite-agent meta-data get "estf-tf-ip-$ESTF_META_ID")
./playbooks/stack_testing/ci/buildkite_stack_testing.sh
