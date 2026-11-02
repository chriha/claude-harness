# Harness config
<!-- eval overlay: _shared/repo/.claude/harness.md plus one Plan-first trigger; keep the rest in sync with it -->

## Tracker
tracker: github
forge: github

## Commands
test: bash test.sh
static:
format:
build:
setup-worktree:

## Scripts
test_file_glob: `tests/*.sh`
red_check_test_cmd: `bash test.sh`

## Branch & commits
branch types: fix|feature|refactor|chore|docs
commit types: feat|fix|docs|style|refactor|perf|test|chore|ci
max subject length: 72
ticket id in commit subject: no
Co-Authored-By: Claude <noreply@anthropic.com>

## Plan-first triggers
- A new config file or config format (users' files must keep working across releases).

## Self-check

## Test conventions
`tests/<script>.sh` holds the cases for `<script>.sh`, compared with `eq`; `test.sh` runs them all.

## Never
- Change dependencies without approval.
