# Harness conventions (read this before writing or editing any skill, brief or script)

## Layers — project always wins
1. **Plugin defaults** (this dir): `skills/`, `briefs/`, `adapters/`, `bin/`, `packs/`, `templates/`, `agents/`, `hooks/` (the last two are not overridable).
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
- `## Models` — `implementer_model:` `sonnet` (default) | `opus` (whole-session opus implementer; see § Implementer models and consults).
Missing section = generic defaults apply. The briefs say "per harness.md § <Section>".

## Tracker / forge adapters
Briefs and skills speak in **operations**, never in CLI strings. `adapters/<name>.md` maps each operation to exact commands:
read-ticket, list-tickets, list-triage, edit-description-section, comment, add/remove-label, assign-me, set-priority, accept-triage, close-not-planned, close-duplicate, create-ticket, blockers (read/add), list-prs, create-draft-pr, pr-diff, pr-comments (inline + general), edit-pr-base, pr-state-of-branch, closing-keyword, ticket-id regex, collision-search.
`adapters/_template.md` lists every operation to fill in for a new platform.

## Paths
`<repo>` main checkout (absolute) · `<wt>` = `<repo>/.user/worktrees/issue-<id>` · `<report>` = `<repo>/.user/reports/issue-<id>.md` · run log `<repo>/.user/runs/<YYYY-MM-DD-HHMM>.md` (one per `/harness:work` run) · cleaned tickets' reports move to `<repo>/.user/reports/archive/issue-<id>-<YYYY-MM-DD>.md` · `harness-sync` prunes `.user/runs/` and `.user/reports/archive/` files older than 90 days · `.user/` is gitignored (init ensures it).

## Hard rules are enforced in code
A brief states a rule; a hard rule (one that must never be broken) also gets a check, so a violating call is refused, not trusted
not to happen:
- **`hooks/hooks.json` → `bin/harness-guard`** (PreToolUse on Bash/Edit/Write/MultiEdit/NotebookEdit). Scope: calls from a
  `harness:*` agent (`agent_type` in the hook input; Claude Code sets it for sub-agent calls only) or targeting/running under
  `<repo>/.user/worktrees/`; everything else passes untouched. Refuses force-push (any flag form, `+refspec`), `gh pr merge|ready`,
  `gh pr review --approve`, `git commit --no-verify|-n`, Edit/Write on lockfiles and `go.mod`/`go.sum`, writes under
  `.user/worktrees/_main`. Each deny reason names the rule and its brief — keep them in step when a brief changes. Text matching,
  not a sandbox. Tests: `tests/run.sh`.
- **Plugin agents `agents/{triager,implementer,verifier}.md`** — `/harness:work` spawns `harness:<role>`, never `general-purpose`.
  The read-only roles use `disallowedTools: Edit, Write, MultiEdit, NotebookEdit` (not `tools:`, so MCP tools stay); they keep Bash
  for tracker writes and focused test runs. The agent body only points at the brief — the brief (resolved, overridable) is the
  source of truth.
- **Settings `deny`** in `templates/settings.base.json` — backstop for never force-push / merge / mark ready; `/harness:init`
  unions it into `.claude/settings.json`, `/harness:doctor` flags missing entries. It applies to interactive sessions too, and
  prefix patterns can't catch combined flags (`-uf`) — the guard does.
- A new hard rule → add it to the brief **and** to `harness-guard` with a test (and to `deny` when a permission pattern can express it).

## Implementer models and consults
`harness-candidates`, the triager and `/harness:work` follow it; the implementer brief adopts it in #34's slice 3.
The implementer session runs on **sonnet** and is the only agent that writes code. `implementer_model: opus` in harness.md
§ Models opts a project in to a whole-session opus implementer (default `sonnet`; nothing else picks opus for the session — not
plan-approved rows, not the triager). The session calls short-lived consult sub-agents; each prompt carries the ticket, the
specific question, the relevant findings and the diff — never the session transcript — and the brief fixes the reply format.
- **Haiku auditor** — mechanical, checkable work only; replies are lists of `file:line`, never conclusions: the Self-check audits
  over the diff (functions that don't exist, duplicated helpers, swallowed errors, unquoted shell/SQL), caller and sibling-pattern
  lookups, the scope/size check (files the ticket doesn't name, the ~400-line limit). Run in parallel in one message. Gate
  exploration stays with the session.
- **Opus advisor** — at four fixed triggers only, never "when it feels big":
  1. **Gate** — a plan-first trigger is uncertain → replies `just-solve` | `plan` | `needs-info` + one line why.
  2. **Plan** — writes the `## Plan` block.
  3. **Stuck fix** — after the 2nd failed attempt of the 3-attempt fix budget → a diagnosis from the failing output and the diff.
     The `checks-red` retry respawns the implementer on opus only when this consult already ran (its RESULT carries
     `· consult: stuck-fix` after the class).
  4. **Sign-off** — replaces the per-finding validators of the review step: gets both reviewers' merged findings and the diff,
     drops false positives, adds misses, and does one short re-check after the fix commit. Opus when changed lines > 200 (the
     review step's count after `exclude_from_size`, same cutoff as the `/code-review` level) or the ticket is plan-approved;
     sonnet otherwise.
- The report's `## Review` records each consult (role, model, trigger) and its token use next to the review sub-agents' tokens;
  `harness-retro` counts them.

## Behaviour is checked by evals
`tests/run.sh` covers `bin/`; `evals/<case>/case.yaml` (`claude plugin eval`) covers how agents behave under a brief/skill.
- **A brief/skill behaviour change updates or adds an eval case**; run it before and after the change and compare with
  `bin/harness-eval-diff` (per case `prev → new`, `DROP` on a fall). A new case is checked once by hand: planting a regression
  in the brief it guards lowers its score (note it in the PR).
- Cases run offline: `case.yaml` names `scaffold.sh`, which calls `_shared/scaffold.sh` — throwaway repo with a bare `origin`,
  case `fixtures/`, a fake `gh` first on PATH (answers adapter operations from fixture JSON, logs calls to `.harness-eval/gh.log`),
  git ref logs (`git.log`, `origin.log`); optional `setup.sh` for extra state. Graders score 0–1 from those logs and the reply.
- Run: `claude plugin eval plugins/harness [--case '<glob>'] --scaffold --ablation none --allow-tools Bash Write Edit --max-cost-usd <usd>`.
  Always cap the cost. `--ablation none` because the scaffold puts the plugin's `bin/` on PATH for both arms (a no-plugin arm
  measures nothing). Results land in `evals/results/` (gitignored).

## Style
Terse imperative briefs, no prose padding. Orchestrators stay thin (route only). Sub-agent final reply = a single RESULT block/line defined in its brief.
Skills are named without prefix; the plugin namespace gives `/harness:<name>`.

## Optional harness.md keys/sections used by specific skills
`## Verify` (verify, see its header) · `## Ratchets` (`name: command printing a number`, harness-retro) · `arch_test:` (arch-loop) ·
`metrics_doc:` (default `docs/harness-metrics.md`) · `sentry: true`. Optional project file `.claude/harness/architecture-domains.md`.
