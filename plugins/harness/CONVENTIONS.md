# Harness conventions (read this before writing or editing any skill, brief or script)

## Layers — project always wins
1. **Plugin defaults** (this dir): `skills/`, `briefs/`, `adapters/`, `bin/`, `packs/`, `templates/`.
2. **Project config** `<repo>/.claude/harness.md` — facts about the project (commands, triggers, forge, tracker). Created once by `/harness:init`; owned by the project.
3. **Project overrides** `<repo>/.claude/harness/<same relative path as in the plugin>` — a file here **replaces** the plugin file of the same path (e.g. `briefs/implementer.md`, `briefs/review-criteria.md`, `adapters/github.md`). Nothing is merged; copy the default and edit it only when config is not enough.

Resolution is always done with the `harness-resolve` command (in `bin/`, on PATH):
`harness-resolve briefs/implementer.md` prints the absolute path of the override if it exists, else the plugin default.
Skills and briefs never hardcode `${CLAUDE_PLUGIN_ROOT}` paths for files that can be overridden; they say "resolve `briefs/x.md`".
Sub-agent prompts get the **resolved absolute path** ("Read and follow `<abs path>`").

## harness.md (project config, markdown; scripts read `key: value` lines — `harness-config key` drops a trailing `<!-- -->` and wrapping backticks)
Sections the briefs refer to by name — keep these headings:
- `## Tracker` — `tracker: github` · `forge: github` · adapter names resolve to `adapters/<name>.md`; labels in use; priority label scheme.
- `## Commands` — `test:`, `static:` (lint/static analysis, may be empty), `format:` (check cmd, must print nothing/exit 0), `build:`, `setup-worktree:` (run once in a fresh worktree, may be empty), `test-affected:` (how to run a subset; `{files}` placeholder).
- `## Scripts` — `red_check_test_cmd:` (`{files}`/`{packages}` placeholders), `test_file_glob:` (git pathspec, e.g. `**/*_test.go`), `exclude_from_size:` (pathspecs excluded from the changed-line count).
- `## Branch & commits` — branch types, branch regex, commit types, max subject length, whether a ticket id goes in the commit subject, `Co-Authored-By` line.
- `## Plan-first triggers` — project-specific list that extends the generic gate in `briefs/implementer.md`.
- `## Self-check` — project-specific "no X" list run before each commit.
- `## Test conventions` — what a good test looks like here (feeds `review-criteria.md` "Test quality").
- `## Never` — hard rules (deps changes need approval, no migrations without plan, ...).
Missing section = generic defaults apply. The briefs say "per harness.md § <Section>".

## Tracker / forge adapters
Briefs and skills speak in **operations**, never in CLI strings. `adapters/<name>.md` maps each operation to exact commands:
read-ticket, list-tickets, edit-description-section, comment, add/remove-label, create-ticket, blockers (read/add), list-prs, create-draft-pr, pr-diff, pr-comments (inline + general), edit-pr-base, pr-state-of-branch, closing-keyword, ticket-id regex, collision-search.
`adapters/_template.md` lists every operation to fill in for a new platform.

## Paths
`<repo>` main checkout (absolute) · `<wt>` = `<repo>/.user/worktrees/issue-<id>` · `<report>` = `<repo>/.user/reports/issue-<id>.md` · `.user/` is gitignored (init ensures it).

## Style
Terse imperative briefs, no prose padding. Orchestrators stay thin (route only). Sub-agent final reply = a single RESULT block/line defined in its brief.
Skills are named without prefix; the plugin namespace gives `/harness:<name>`.

## Optional harness.md keys/sections used by specific skills
`## Verify` (verify, see its header) · `## Ratchets` (`name: command printing a number`, harness-retro) · `arch_test:` (arch-loop) ·
`metrics_doc:` (default `docs/harness-metrics.md`) · `sentry: true`. Optional project file `.claude/harness/architecture-domains.md`.
