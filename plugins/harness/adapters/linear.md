# Adapter: Linear (issues via the Linear MCP server; forge stays GitHub or whatever `forge:` names)

Tracker only. `<id>` = the issue identifier `<TEAM>-<n>` (e.g. `ENG-123`), referenced as is. Ticket id regex: `([A-Z][A-Z0-9]+-\d+)`.
Worktree name: `issue-<id lowercase>`. Closing keyword: `Fixes <id>` in the PR description (Linear's GitHub integration moves the
issue to done on merge). Reference form (non-final plan slice, must not close): `Refs <id>`.
Branch ↔ ticket: branch `<type>/<id lowercase>-<slug>` (e.g. `fix/eng-123-null-total`); Linear links the PR from the id in the branch.

Config, harness.md § Tracker (`harness-config key …`):
- `linear_mcp:` the MCP server name in this project's/user's MCP config (default `linear`). Tools below are
  `mcp__<linear_mcp>__<tool>` — written as `<tool>` here.
- `linear_team:` team key (e.g. `ENG`) — scopes every list/create.
- `linear_accept_state:` state an accepted triage ticket moves to (default `Todo`).

MCP parameter names follow the official Linear MCP server; if yours differs, copy this file to
`<repo>/.claude/harness/adapters/linear.md` and fix the rows.

## Tracker operations

| Operation | Call |
|---|---|
| read-ticket | `get_issue` (`id`) + `list_comments` (`issueId`) — fields used: identifier, title, description, labels, state (name + type), priority, assignee, createdAt, url |
| list-tickets (mine, open) | `list_issues` (`team`, `assignee: "me"`, state type `unstarted`/`started`/`backlog`) |
| list-triage | `list_issues` (`team`, state type `triage`) **plus** `list_issues` (`team`, `label: "triage"`, not completed/canceled); union by id |
| search-tickets | `list_issues` (`team`, `query: "<kw>"`, `includeArchived` for "all") |
| create-ticket | `save_issue` (`team`, `title`, `description`, `labels`, `assignee: "me"`); triage tickets: no assignee, `state: "Triage"` when the team has triage enabled, plus the `triage` label |
| edit-description | `get_issue` right before writing → change only your sections → `save_issue` (`id`, `description`: the full new text) |
| comment | `create_comment` (`issueId`, `body`) |
| add-label / remove-label | `save_issue` (`id`, `labels`: the **full** new set — read the current labels first; the call replaces them) |
| create-label (once) | `list_issue_labels` (`team`) → missing → `create_issue_label` (`name`, `teamId`, `color`) |
| assign-me | `save_issue` (`id`, `assignee: "me"`) |
| set-priority | `save_issue` (`id`, `priority`: 1 urgent · 2 high · 3 medium · 4 low · 0 none) |
| accept-triage | one `save_issue`: `labels` without `triage`, `assignee: "me"`, and — if the state type is `triage` — `state: <linear_accept_state>` |
| close-not-planned | `save_issue` (`id`, `state`: the team's `canceled`-type state, from `list_issue_statuses`) |
| close-duplicate | `save_issue` (`id`, `duplicateOf: "<other id>"`) — Linear moves it to the Duplicate state |
| blockers-read | `get_issue` (`id`, `includeRelations: true`) → relations of type `blocked by` |
| blockers-add | `save_issue` (`id`, `blockedBy: ["<blocker id>"]`) |
| related | `save_issue` (`id`, `relatedTo: ["<other id>"]`) **and** `Related: <id>` under `## Reference` |
| in-flight | state type `started` with an open PR on the forge whose branch contains `<id lowercase>`; no label |
| collision-search | the forge's `list-prs` (open) + 2–3 `search-tickets` on the `## Touches` names |
| ticket-of-pr | the id regex on the PR description (`Fixes`/`Refs`), then the branch name, then the commit log |
| harness-issues | `list_issues` (`team`, `label: "agent-harness"`, `query: "<key>"`, `includeArchived: true`) |
| status-of-ticket | state type: `triage` · `backlog`/`unstarted` (ready) · `started` (in progress / in review) · `completed` · `canceled` |

Priority: Linear's native field (1 urgent … 4 low; 0 none sorts last) — no priority labels.
Type labels: `bug`, `feature`, `improvement` (team labels). Special labels: `on hold`, `ready-for-human` (not for agents) · `needs-info` ·
`planning` · `triage` · `agent-harness`. **Triage** = state type `triage` **or** the `triage` label.
Dedupe key for harvest issues: first line of the description `Key: <key>`.

## Forge operations
None — use the adapter named by `forge:` (e.g. `adapters/github.md`).

## Rules
Agents never move an issue's state, change its assignee or close it — except where a skill says so with the human's approval
(`triage`: accept / dismiss / duplicate). The forge integration moves state on PR open/merge.

## Allow-list fragment (for `.claude/settings.json`; replace `linear` with your `linear_mcp`)
`mcp__linear__get_issue`, `mcp__linear__list_issues`, `mcp__linear__list_comments`, `mcp__linear__list_issue_labels`,
`mcp__linear__list_issue_statuses`, `mcp__linear__list_teams` (read-only); writers (`save_issue`, `create_comment`,
`create_issue_label`) are granted per skill via `allowed-tools`.
