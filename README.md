# claude-harness

One Claude Code plugin that gives any repo the same ticket → plan → implement → review pipeline, without copying files between projects.

## Install (once, user scope)

```
/plugin marketplace add chriha/claude-harness
/plugin install harness@chriha
```
Or from a shell: `claude plugin marketplace add chriha/claude-harness && claude plugin install harness@chriha`.

Update with `/plugin marketplace update chriha` followed by `claude plugin update harness`. There's no `version` in `plugin.json`,
so updates track commit SHAs. Add a `version` there if you'd rather release explicitly.

**Developing the plugin:** to have local edits apply at the next session start or `/reload-plugins`, add your clone as the marketplace
instead: `/plugin marketplace add /path/to/claude-harness`.

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

`init` · `doctor` · `ticket` · `triage` · `work` · `review` · `work-on-comments` · `verify` · `harness-retro` · `arch-loop`
Invoke as `/harness:<name>`.

## Platforms

`adapters/github.md` (tracker + forge) and `adapters/linear.md` (tracker, via the Linear MCP server; `ticket`/`triage` work there; `/harness:work`
needs a Linear class in `harness-candidates` first) ship. Add GitLab/Jira by copying `adapters/_template.md` (to the plugin for all projects, or to
`<repo>/.claude/harness/adapters/` for one) and setting `tracker:` / `forge:` in harness.md. `harness-candidates` has a `GitHub` class to mirror
for a new tracker; `harness-worktree`/`harness-sync` have a `forge` switch.

## Packs

`packs/laravel`, `packs/go`: `harness.md` defaults, `settings.json` allow-list, rules (laravel), githooks (laravel). See each README.

## Layout

```
.claude-plugin/marketplace.json
plugins/harness/{.claude-plugin,skills,briefs,adapters,bin,packs,templates,CONVENTIONS.md}
```
