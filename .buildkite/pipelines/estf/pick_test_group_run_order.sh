#!/bin/bash 

set -eu 

# Clone kibana repo from git reference
git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git
cd kibana 

# Checkout kibana commit
#git checkout -f $(buildkite-agent meta-data get "estf-kibana-hash-$ESTF_META_ID")

# eventually replace with source of a file from kibana repo @spalger to create 
export TEST_GROUP_TYPE_UNIT="Jest Unit Tests"
export TEST_GROUP_TYPE_INTEGRATION="Jest Integration Tests"
export TEST_GROUP_TYPE_FUNCTIONAL="Functional Tests"

echo '--- Pick Test Group Run Order'
node "$(dirname "${0}")/pick_test_group_run_order.js"

