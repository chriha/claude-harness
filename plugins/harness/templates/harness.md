# Harness config

Read by the `/harness:*` skills and briefs (see the plugin's CONVENTIONS.md). Owned by this project — edit freely.
To change a whole brief/adapter instead, copy it to `.claude/harness/<same path>` (it replaces the plugin file).

## Tracker
tracker: github
forge: github
<!-- labels/priority scheme differing from the adapter's defaults go here -->

## Commands
test: 
static: 
format: 
build: 
setup-worktree: 
test-affected: 

## Scripts
test_file_glob: 
red_check_test_cmd: 
exclude_from_size: 

## Branch & commits
branch types: fix|feature|refactor|chore
commit types: feat|fix|docs|style|refactor|perf|test|chore|ci
max subject length: 72
ticket id in commit subject: no
Co-Authored-By: Claude <noreply@anthropic.com>

## Plan-first triggers
<!-- project-specific "this needs a plan first" cases, one per line -->

## Self-check
<!-- project-specific "no X" checks before each commit -->

## Test conventions
<!-- what a good test looks like here -->

## Never
- Change dependencies without approval.
