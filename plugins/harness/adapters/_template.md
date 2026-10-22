# Adapter template — copy to `adapters/<name>.md` (plugin) or `<repo>/.claude/harness/adapters/<name>.md` (one project)

Then set `tracker: <name>` and/or `forge: <name>` in the project's `.claude/harness.md` (`## Tracker`).
Fill in the exact command / MCP call for **every** row, or write `unsupported` and say what the skill should do instead.
See `github.md` for a complete example.

Header: ticket reference format · ticket id regex · worktree name (`issue-<id>`) · closing keyword (how a PR/MR closes the ticket, or "tracker moves status from the id in the title") · branch ↔ ticket rule.

## Tracker operations
read-ticket · list-tickets (mine, open/todo) · search-tickets · create-ticket · edit-description (partial edit rules!) · comment · add-label / remove-label · create-label · blockers-read · blockers-add · related · in-flight · collision-search · ticket-of-pr · harness-issues (dedupe by key) · status-of-ticket
Plus: priority scheme · type labels · special labels (on hold, ready-for-human, needs-info, planning, triage, agent-harness) and their names on this tracker.

## Forge operations
list-prs · pr-of-branch · view-pr · pr-diff · create-draft-pr · edit-pr-base · pr-template · comment-pr (general + inline) · review-threads · reply-to-comment · resolve-thread · merged/closed state · pr-mine-open

## Rules
What agents must never do on this platform (merge, mark ready, close tickets, change status/assignee).

## Allow-list fragment
Read-only commands/MCP tools for `.claude/settings.json`.
