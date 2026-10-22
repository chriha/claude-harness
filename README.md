# claude-harness

One Claude Code plugin that gives any repo the same ticket → plan → implement → review pipeline, without copying files between projects.

## Install (once, user scope)

```
/plugin marketplace add /Users/chris/Development/projects/claude-harness
/plugin install harness@chris-harness
```
Local-directory plugin: edits are live at the next session start or `/reload-plugins`. Once pushed to a git remote, use that URL
instead; then `claude plugin update harness` pulls new versions (bump `version` in `plugin.json`, or omit it to follow commit SHAs).

## Add to a project

`/harness:init` in the repo — detects stack/forge/tracker, writes `.claude/harness.md`, copies the stack pack once, merges permissions.
That is the only per-project footprint besides optional overrides.

## Layers (project always wins)

| Layer | Where | Updated by |
|---|---|---|
| Plugin defaults: skills, briefs, adapters, scripts (`bin/`) | this repo | `git pull` / plugin update — **all projects at once** |
| Project config | `<repo>/.claude/harness.md` | you; facts only (commands, triggers, forge) |
| Project override | `<repo>/.claude/harness/<same path as in the plugin>` | you; replaces the plugin file wholesale |
| Pack files copied once (rules, githooks) | `<repo>/.claude/rules`, `.githooks` | you; `/harness:doctor` shows drift from upstream |

Skills and briefs resolve every overridable file through `harness-resolve`, so an override needs no registration.

## Skills

`init` · `doctor` · `ticket` · `work-tickets` · `local-code-review` · `work-on-comments` · `verify` · `harness-retro` · `architecture-loop`
Invoke as `/harness:<name>`.

## Platforms

`adapters/github.md` ships. Add GitLab/Linear/Jira by copying `adapters/_template.md` (to the plugin for all projects, or to
`<repo>/.claude/harness/adapters/` for one) and setting `tracker:` / `forge:` in harness.md. `harness-candidates` has a `GitHub` class to mirror
for a new tracker; `harness-worktree`/`harness-sync` have a `forge` switch.

## Packs

`packs/laravel`, `packs/go`: `harness.md` defaults, `settings.json` allow-list, rules (laravel), githooks (laravel). See each README.

## Layout

```
.claude-plugin/marketplace.json
plugins/harness/{.claude-plugin,skills,briefs,adapters,bin,packs,templates,CONVENTIONS.md}
```
