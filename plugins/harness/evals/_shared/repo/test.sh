#!/usr/bin/env bash
# Runs every tests/*.sh; exits non-zero on the first failure.
set -euo pipefail
cd "$(dirname "$0")"
for t in tests/*.sh; do bash "$t"; done
echo ok
