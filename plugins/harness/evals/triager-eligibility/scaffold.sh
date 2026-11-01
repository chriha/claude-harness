#!/usr/bin/env bash
# Case scaffold: the shared fixture repo, fake gh and this case's fixtures (see ../_shared/scaffold.sh).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec bash "$here/../_shared/scaffold.sh" "$here"
