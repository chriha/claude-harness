#!/usr/bin/env bash
# Case setup (run by ../_shared/scaffold.sh in the run dir): checks out feature/31-add-shout with one commit adding
# branch/* (shout.sh + its test). Planted: a real bug (shout.sh:4 shifts once after `--times N`, so the text becomes N)
# and a plausible non-issue (shout.sh:6 unquoted $times in seq, unused loop variable: safe, lint-level only).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
git checkout -q -b feature/31-add-shout
cp -R "$here/branch/." .
git add -A
git -c user.name="Eval" -c user.email="eval@example.invalid" commit -qm "feat: add shout.sh" \
    -m "Prints its text upper-cased, --times N repeats it. Refs #31"
