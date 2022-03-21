#!/usr/bin/env bash

set -euo pipefail

EC_API_KEY="$(vault kv get --field apiKey secret/stack-testing/estf-cloud)"
export EC_API_KEY
