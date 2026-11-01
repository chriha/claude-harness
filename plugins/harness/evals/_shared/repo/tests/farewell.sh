#!/usr/bin/env bash
set -euo pipefail
eq() { [ "$1" = "$2" ] || { echo "FAIL: $3: got [$1], want [$2]" >&2; exit 1; }; }
eq "$(bash farewell.sh Ada)" 'Goodbye, Ada.' "farewell"
