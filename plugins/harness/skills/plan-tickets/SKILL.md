---
name: plan-tickets
description: Walk through a planned ticket (label planning) with me, answer its questions, finalize the plan and approve it for /harness:work-tickets
argument-hint: "[ticket id]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, AskUserQuestion, Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(find:*), Bash(date:*), Bash(harness-*:*), Bash(gh issue:*), Bash(gh pr list:*), Bash(gh api:*), Bash(gh label:*), mcp__codegraph__codegraph_explore
---

Finalize the plan of one big ticket with the human, then approve it so `/harness:work-tickets` implements it. Ticket shape, labels,
collision check: `harness-resolve briefs/tickets.md`; operations from the adapter (`harness-resolve adapters/<tracker>.md`, tracker per
`.claude/harness.md`). Plan format: `harness-resolve briefs/implementer.md` ("Planning").

Background: an implementer that hits a plan-first trigger doesn't code. It writes `## Plan` (marker `<!-- work-tickets plan -->`;
Approach, Trigger, PRs, Risks, Questions) and adds `planning`. Removing `planning` approves the plan; the next unshipped PR slice is implemented.

**This skill writes no application code, runs no tests, and never touches git.** It only writes to the tracker: the description
(`## Plan`, `## Decision`, `## Touches`, `## Status`), `Changed` comments, labels and split-off tickets.

Argument (optional): a ticket id.
- **Given** → `read-ticket` (comments, blockers). It must be open, labeled `planning` and have a plan (`## Plan`, or an old plan
  comment — fold it, `tickets.md`). Otherwise say what it is and stop: `needs-info` → `/harness:ticket <id>`; no plan/no `planning` →
  nothing to plan; closed → nothing to do.
- **Omitted** → `list-tickets` (mine, open) with `planning`, highest priority first then oldest. None → say so and stop.

## Step 1 — Load & brief

- Read description (incl. `## Plan`) and comments in full, plus `## Problem` of related/blocking tickets.
- Verify the plan against the code before asking: files each PR slice lists exist (or are sensibly new) and the slices still match
  the current code — other tickets may have landed. Read from `<repo>/.user/worktrees/_main` if it exists, else the repo; CodeGraph
  first when `.codegraph/` exists. Note drift; it may become a question.
- **Collision check** (`tickets.md`) on the files the slices list. Hit → ask with the Step 2 questions: `Add blocked-by <id>` /
  `Relate only` / `Merge into <id>`; apply via `blockers-add` / `Related:` / a description update + `Changed` comment.
- Brief (≤ 10 lines): problem in one line, approach, slices as a numbered one-liner list, file count, open question count.

## Step 2 — Ask the questions

Ask **every** question under `### Questions`, personally, via `AskUserQuestion`: one call per question (up to 4 per call only when small
and independent); question text stands alone; options = the question's (2–4), the `_recommended_` one first with `(Recommended)`; `preview`
for code/response shapes.
- **Add your own questions** for drift from Step 1 and plan gaps: missing tests, API contract/spec conformance, migration/backfill,
  deploy order, docs update, splitting — plus harness.md § Plan-first triggers.
- An answer that changes the premise of later questions → rephrase/drop them first. "Split this ticket" → note the slices that move out.
- Postponed → stop: add to `### Questions` and `## Open questions`, keep `planning`, report it as still planning.

## Step 2b — Confirm understanding

Restate problem + chosen approach in 2–3 lines, checked against code/docs; confirm: `Correct (Recommended)` / `Not quite`.

## Step 3 — Update the plan

Rewrite `## Plan` via `edit-description` (keep marker and format):
- Replace `### Questions` with `### Decisions`: one bullet per question — gist → decision (+ short why). Fold the same into `## Decision`
  (opens with `Understanding:`; each bullet names the alternatives rejected and why) and drop answered `## Open questions`.
- Rewrite **Approach**, `### PRs`, `### Risks` to reflect the decisions — executable **without** reading the decisions. Each slice keeps
  files, `no behaviour change` | `behaviour change`, **Done when:**; ≤ ~400 lines, one concern.
- Documented behaviour changes → add a docs slice. Only tests count as quality work: each **Done when:** includes its tests; drop any
  slice about style/lint/static analysis.
- Ensure `## Touches`. Append `_Approved with the human (YYYY-MM-DD)._` as the last line.
- **Plan optimization (mandatory last check):** which slices can run in parallel, would reordering allow more; per slice name the model —
  haiku (simple, low risk), sonnet (medium), opus (complex/high error potential).
- **Split** (if chosen): `create-ticket` for each carved-out slice (assignee me, type label, normal shape, `## Reference` back to this
  ticket, `blockers-add` if it must land after); several slices → its own approved `## Plan` (no `planning`). Remove moved slices here.

Show the updated `### PRs`; ask once: **"Approve this plan for /harness:work-tickets?"** — `Approve (Recommended)` / `Adjust`.

## Step 4 — Approve & report

- `## Status` (plan approved — next: first unshipped slice via `/harness:work-tickets`), `Changed` comment, `remove-label planning`.
- Report: id + title, decisions (one line each), final slice and file count, split-off tickets, how many of my tickets remain `planning`.

End with: **"Approved — `/harness:work-tickets <id>` will implement the first slice."**
