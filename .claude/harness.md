# Harness config

Read by the `/harness:*` skills and briefs (see the plugin's CONVENTIONS.md). Owned by this project — edit freely.
To change a whole brief/adapter instead, copy it to `.claude/harness/<same path>` (it replaces the plugin file).

## Tracker
tracker: github
forge: github
<!-- labels/priority scheme differing from the adapter's defaults go here -->
<!-- tracker: linear → also linear_mcp: (MCP server name, default linear), linear_team: (team key), linear_accept_state: (default Todo) -->

## Commands
test: bash plugins/harness/tests/run.sh
static:    <!-- none yet; shellcheck isn't installed -->
format:    <!-- none -->
build:    <!-- none; plain bash + markdown -->
setup-worktree:    <!-- none -->
test-affected: bash plugins/harness/tests/run.sh    <!-- single suite; no subsetting -->

## Scripts
test_file_glob: `plugins/harness/tests/**`
red_check_test_cmd: `bash plugins/harness/tests/run.sh`    <!-- appended file args are ignored by run.sh -->
exclude_from_size: 

## Branch & commits
branch types: fix|feature|refactor|chore|docs
commit types: feat|fix|docs|style|refactor|perf|test|chore|ci
commit scope: `harness` for changes under plugins/harness/, e.g. `fix(harness): …`
max subject length: 72
ticket id in commit subject: no
Co-Authored-By: Claude <noreply@anthropic.com>

## Plan-first triggers
- Changing the `.claude/harness.md` key format or CONVENTIONS.md contract (every consuming project depends on it).
- Adding or renaming a skill, brief or adapter.

## Self-check
- No edits under `~/.claude*/plugins/cache/` — change the source in `plugins/harness/`.
- New/changed `bin/` behaviour has a case in `plugins/harness/tests/run.sh`.
- README and CONVENTIONS.md still match skill names and config keys.

## Test conventions
`tests/run.sh` builds throwaway git repos in a temp dir and asserts script output with `eq`; one block per behaviour, referencing the issue number.

## Never
- Change dependencies without approval.
