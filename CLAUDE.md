# claude-harness

Source of the `harness` Claude Code plugin: a ticket → plan → implement → review pipeline for any repo. User docs: `README.md`; the contract between skills, briefs and project config is in `plugins/harness/CONVENTIONS.md`.

## Commands
- Test: `bash plugins/harness/tests/run.sh` (needs git, go)
<!-- keep in sync with .claude/harness.md § Commands -->

## Layout
- `.claude-plugin/` — marketplace manifest (`chriha`)
- `plugins/harness/skills/` — `/harness:*` skills
- `plugins/harness/briefs/` — subagent briefs (implementer, verifier, triager, review criteria …)
- `plugins/harness/adapters/` — tracker/forge adapters (github, linear, `_template`)
- `plugins/harness/packs/` — stack packs (laravel, go): rules, githooks, settings
- `plugins/harness/templates/` — files `/harness:init` writes into projects
- `plugins/harness/bin/` — helper scripts on PATH; tested by `tests/run.sh`

## Conventions
- Edit the source here, never the installed copy under `~/.claude*/plugins/cache/`. To test local edits, add this clone as the marketplace (see README).
- Skills, briefs and adapters must stay consistent with CONVENTIONS.md; change the contract there first.
- `bin/` scripts are portable bash (macOS + Linux); every behaviour change gets a case in `tests/run.sh`.

## Git
- Branches: `<type>/<id>-<slug>`; Conventional Commits with scope `harness` for plugin changes; PRs closed via the tracker's closing keyword. Agents open drafts and never merge or mark ready.

## Agent workflow
Ticket pipeline via the `harness` plugin: `/harness:ticket`, `/harness:work`, `/harness:review`, `/harness:work-on-comments`.
Project config: `.claude/harness.md`; overrides: `.claude/harness/`.
