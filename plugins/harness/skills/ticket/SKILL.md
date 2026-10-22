---
name: ticket
description: Report a bug, change request or feature and file it as a ready ticket for /harness:work-tickets — or pass a ticket id to answer a needs-info ticket's open questions / finalize and approve a planning ticket's plan
argument-hint: "[free text | ticket id]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, AskUserQuestion, Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(find:*), Bash(date:*), Bash(harness-*:*), Bash(gh issue:*), Bash(gh pr list:*), Bash(gh api:*), Bash(gh label:*), mcp__codegraph__codegraph_explore
---

Turn something the human reports — a **bug**, a **change request** or a **new feature** — into an actionable ticket that
`/harness:work-tickets` picks up. Ticket shape, labels, collision check: `harness-resolve briefs/tickets.md`. Operations
(`read-ticket`, `create-ticket`, …): the adapter named in `.claude/harness.md` § Tracker (`harness-resolve adapters/<tracker>.md`).
Plan-first criteria and plan format: `harness-resolve briefs/implementer.md` ("Gate first", "Planning") plus harness.md § Plan-first triggers.

**This skill writes no application code, runs no tests, and never touches git.** It only writes to the tracker.

Argument:
- **A ticket id** → `read-ticket`, then by label: `needs-info` → **resume mode**; `planning` → **plan mode** (both below). Neither
  label → say what it is and stop without writing (closed → nothing to do).
- **Free text** → the report flow, Steps 1–4.
- **Omitted** → ask via `AskUserQuestion` (options `Bug` / `Change request` / `Feature` / `Plan a ticket`; details via "Other" or a
  follow-up). `Plan a ticket` → `list-tickets` (mine, open) with `planning`, highest priority first then oldest; none → say so and
  stop, else plan mode on the first.

## Resume mode — answer a `needs-info` ticket

- `read-ticket` (with comments) + `blockers-read`. It must be open and labeled `needs-info`. If not, say what it is and stop without
  writing: no `needs-info` → nothing to answer; `planning` → plan mode; closed → nothing to do.
- Read description and comments in full, plus tickets it references and the docs it points to. Brief the human (≤ 10 lines): the
  question, what is blocked, how the code behaves today (file:line).
- Break `## Open questions` into individual decisions; ask them **one at a time** via `AskUserQuestion` (as in Step 2), follow-ups
  until the answer is concrete. "Not now" → record what was decided so far under `## Open questions`, keep the label, stop.
- Confirm understanding (Step 2b) before drafting.
- Draft: replace `## Open questions` with `## Decision` (an `Understanding:` bullet, then one bullet per answer, each naming the
  alternatives rejected and why); update acceptance criteria and `## Touches` where the answers change them. Never edit `## Problem`
  (`tickets.md`, "Requirements are human-owned"). Only tests count as quality work: no criteria about style/lint/static analysis.
- Re-check the plan-first criteria and run the collision check (Step 1). Plan-first now applies → add a `## Plan` as in Step 3.
- Show the draft; ask once: **"Update this ticket?"** — `Update (Recommended)` / `Adjust`.
- Then `edit-description`, `remove-label needs-info` (+ `blockers-add` for collision hits, `Related:` lines under `## Reference`),
  `## Status` = `Ready for /harness:work-tickets.`, a `Changed` comment. Report id + url; mention tickets that reference this one
  and may now be unblocked (`search-tickets` on the id).

End with: **"Ready — `/harness:work-tickets <id>` will pick it up."**

## Plan mode — finalize a `planning` ticket's plan

Finalize the plan of one big ticket with the human, then approve it so `/harness:work-tickets` implements it.

- The ticket must be open, labeled `planning` and have a plan (`## Plan`, or an old plan comment — fold it, `tickets.md`). Otherwise say what it is and stop: `needs-info` → resume mode; no plan/no `planning` → nothing to plan.
- Background: an implementer that hits a plan-first trigger doesn't code. It writes `## Plan` (marker `<!-- work-tickets plan -->`;
  Approach, Trigger, PRs, Risks, Questions) and adds `planning`. Removing `planning` approves the plan; the next unshipped PR slice is implemented.

### P1 — Load & brief

- Read description (incl. `## Plan`) and comments in full, plus `## Problem` of related/blocking tickets.
- Verify the plan against the code before asking: files each PR slice lists exist (or are sensibly new) and the slices still match
  the current code — other tickets may have landed. Read from `<repo>/.user/worktrees/_main` if it exists, else the repo; CodeGraph
  first when `.codegraph/` exists. Note drift; it may become a question.
- **Collision check** (`tickets.md`) on the files the slices list. Hit → ask with the P2 questions: `Add blocked-by <id>` /
  `Relate only` / `Merge into <id>`; apply via `blockers-add` / `Related:` / a description update + `Changed` comment.
- Brief (≤ 10 lines): problem in one line, approach, slices as a numbered one-liner list, file count, open question count.

### P2 — Ask the questions

Ask **every** question under `### Questions`, personally, via `AskUserQuestion`: one call per question (up to 4 per call only when small
and independent); question text stands alone; options = the question's (2–4), the `_recommended_` one first with `(Recommended)`; `preview`
for code/response shapes.
- **Add your own questions** for drift from P1 and plan gaps: missing tests, API contract/spec conformance, migration/backfill,
  deploy order, docs update, splitting — plus harness.md § Plan-first triggers.
- An answer that changes the premise of later questions → rephrase/drop them first. "Split this ticket" → note the slices that move out.
- Postponed → stop: add to `### Questions` and `## Open questions`, keep `planning`, report it as still planning.

### P2b — Confirm understanding

Restate problem + chosen approach in 2–3 lines, checked against code/docs; confirm: `Correct (Recommended)` / `Not quite`.

### P3 — Update the plan

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

### P4 — Approve & report

- `## Status` (plan approved — next: first unshipped slice via `/harness:work-tickets`), `Changed` comment, `remove-label planning`.
- Report: id + title, decisions (one line each), final slice and file count, split-off tickets, how many of my tickets remain `planning`.

End with: **"Approved — `/harness:work-tickets <id>` will implement the first slice."**

## Step 1 — Investigate (report flow)

- Classify → label: `bug` (behaviour differs from intent/docs), `improvement` (existing behaviour should differ), `feature` (new).
- **Duplicate check**: `search-tickets` (open and closed) with a few keyword queries; open similar ones. One already covers it →
  show it, ask: `Add to <id>` (fold the new report into its description + `## Status`, `Changed` comment, stop) / `File separately` / `Drop`.
- Look at the code (CodeGraph first when `<repo>/.codegraph/` exists, then grep/read) and the matching docs. Bug → find the cause
  (file:line, what happens vs. what should). Don't run tests or the app.
- List every file the change would create or modify, **including** tests, migrations, docs, README sections. Check it against the
  plan-first criteria. These files/modules become `## Touches`.
- **Collision check** (`tickets.md`) on the Touches. Hit → show it and ask: `Add blocked-by <id>` / `Relate only` / `Merge into <id>`
  (update its description + `Changed` comment, stop).
- Brief the human (≤ 10 lines): what you understood, what the code does today (file:line), likely approach, file estimate,
  just-solve vs. plan-first.

## Step 2 — Ask

Ask everything an implementer would otherwise guess — behaviour, numbers, naming, UX, edge cases, scope, splitting — via
`AskUserQuestion`: standalone question text, 2–4 options, recommended first with `(Recommended)`, `preview` for code/UI/config
shapes, follow-ups until the decision is concrete. No questions is fine if the report is unambiguous. Postponed decision → the
ticket gets `needs-info` (Step 3).

## Step 2b — Confirm understanding

Restate the problem in 2–3 lines, checked against the code/docs (file:line); have the human confirm: `Correct (Recommended)` /
`Not quite` (take the correction, re-investigate if needed, restate). Skip only if the report was already that precise and nothing was asked.

## Step 3 — Draft

```
## Status
Ready for /harness:work-tickets. (needs-info: Waiting on the human to answer `## Open questions`.)

## Problem
<1–5 sentences: what happens vs. what should, with file:line evidence; for features: what's missing and why>

## Decision
- Understanding: <the 2–3 line restatement confirmed in Step 2b>
- <one bullet per answer from Step 2, concrete; name the alternatives rejected and why>

## Acceptance criteria
- [ ] <testable criterion — incl. tests, and "document in <section>" for a product rule>

## Touches
<package, type or dir per line>

## Reference
Reported by the human (YYYY-MM-DD). Docs: <path>. Related: <id>
```

- Title: short, imperative, what to implement.
- **Plan-first** → also a `## Plan` (after `## Touches`; implementer's planning format with the `<!-- work-tickets plan -->` marker, no
  `### Questions` — they were answered). Independent slices → offer to file them as separate tickets.
- **Decision postponed** → `## Open questions` with the concrete options after `## Decision` (keep `Understanding:` and decisions so far).

Show title, body (and plan); ask once: **"File this ticket?"** — `File (Recommended)` / `Adjust` (update, ask again).

## Step 4 — File & report

- Write the body to a scratchpad file, `create-ticket` (assignee me, type label; `needs-info` for a postponed decision). No priority
  label unless the human rated a bug. Missing label → `create-label` first. `Related:` lines under `## Reference`; `blockers-add` for
  `Add blocked-by` hits.
- Plan-first → the plan is in the description **without** the `planning` label — it's approved.
- Report: id + url, title, label, criteria count, file estimate.

End with: **"Ready — `/harness:work-tickets <id>` will pick it up."** (needs-info: **"Filed — answer it with `/harness:ticket <id>`."**)
