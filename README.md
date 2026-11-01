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

## Models

The implementer session runs on sonnet; haiku sub-agents do the mechanical audits (Self-check over the diff, caller lookups,
scope/size), and opus is consulted at four fixed points: an uncertain gate, writing the plan, after the 2nd failed fix attempt,
and the review sign-off (opus above 200 changed lines or on plan-approved tickets, sonnet otherwise). To run the whole implementer session on opus instead,
set `implementer_model: opus` under `## Models` in `.claude/harness.md` (default `sonnet`).
Details: `plugins/harness/CONVENTIONS.md` § Implementer models and consults.

## Guardrails — hard rules in code, not only in prompts

- **Hook** `hooks/hooks.json` → `bin/harness-guard` (PreToolUse). For calls from `harness:*` agents or under `<repo>/.user/worktrees/`
  it refuses force-push, `gh pr merge|ready`, `gh pr review --approve`, `git commit --no-verify`, edits to lockfiles/`go.mod` and writes
  to `.user/worktrees/_main`, with a reason naming the rule and its brief. Your own interactive work elsewhere is untouched.
- **Agents** `agents/{triager,implementer,verifier}.md`: `/harness:work` spawns `harness:<role>`; triager and verifier have no
  Edit/Write/NotebookEdit.
- **Deny list** in `templates/settings.base.json` (force-push variants, `gh pr merge`, `gh pr ready`): `/harness:init` merges it into
  `.claude/settings.json`, `/harness:doctor` flags missing entries. It applies to interactive sessions too: agents open drafts and
  never merge or mark ready, and in this setup neither does Claude for you. Run those yourself.

Details: `plugins/harness/CONVENTIONS.md` § Hard rules are enforced in code.

## Platforms

`adapters/github.md` (tracker + forge) and `adapters/linear.md` (tracker, via the Linear MCP server; `ticket`/`triage` work there; `/harness:work`
needs a Linear class in `harness-candidates` first) ship. Add GitLab/Jira by copying `adapters/_template.md` (to the plugin for all projects, or to
`<repo>/.claude/harness/adapters/` for one) and setting `tracker:` / `forge:` in harness.md. `harness-candidates` has a `GitHub` class to mirror
for a new tracker; `harness-worktree`/`harness-sync` have a `forge` switch.

## Packs

`packs/laravel`, `packs/go`: `harness.md` defaults, `settings.json` allow-list, rules (laravel), githooks (laravel). See each README.

## Evals

`tests/run.sh` covers `bin/`; `plugins/harness/evals/` covers how agents behave under the briefs. Four
`claude plugin eval` cases: `triager-eligibility` (ELIGIBLE vs. needs-info), `verifier-false-finding`
(rejects a planted false finding), `implementer-draft-only` (stops at a draft PR, never merges or closes), `review-planted-bug`
(flags a planted bug). Each case's scaffold builds a throwaway git repo with a bare `origin` and puts a fake `gh` first on PATH
that answers from fixture JSON and logs every call, so runs stay offline; graders read that log, the git ref logs and the reply.

Run by hand after editing `briefs/` or `skills/` — every run is a full Claude session, so always cap the cost:

```bash
claude plugin eval plugins/harness --scaffold --ablation none --allow-tools Bash Write Edit --max-cost-usd 5
claude plugin eval plugins/harness --case 'triager-*' --scaffold --ablation none --allow-tools Bash --max-cost-usd 2
plugins/harness/bin/harness-eval-diff    # per case: prev → new, DROP on a fall, n/a for a new case
```

- `--scaffold` runs the cases' `scaffold.sh` (fake `gh`, fixture repo). `--ablation none`: the scaffold puts the plugin's `bin/` on
  PATH for both arms, so a no-plugin baseline arm would still run the plugin's helpers and briefs and show nothing.
  `--allow-tools Bash` (plus `Write Edit` for `implementer-draft-only`) grants the gated tools the cases use.
- Scores below 1.0 are normal (non-deterministic runs; the CLI exits 1 below `--threshold`, default 1.0). Compare runs with
  `harness-eval-diff` (reads the two newest `aggregate-result.json` under `plugins/harness/evals/results/`, which is gitignored;
  needs jq) rather than reading one run as pass/fail.
- A brief/skill behaviour change updates or adds an eval case.

## Layout

```
.claude-plugin/marketplace.json
plugins/harness/{.claude-plugin,skills,agents,hooks,briefs,adapters,bin,evals,packs,templates,tests,CONVENTIONS.md}
```
