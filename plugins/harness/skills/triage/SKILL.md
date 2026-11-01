---
name: triage
description: Go through the repo's triage tickets with me one by one — verify each against the code, score it against the acceptance criteria, ask the questions that decide it, then accept, refine via /harness:ticket, send to needs-info, dismiss or mark duplicate
argument-hint: "[id …] [--label <label>]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Skill, AskUserQuestion, Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(find:*), Bash(date:*), Bash(mkdir:*), Bash(rm:*), Bash(harness-*:*), Bash(git log:*), Bash(gh issue:*), Bash(gh pr list:*), Bash(gh api:*), Bash(gh label:*), mcp__linear, mcp__codegraph__codegraph_explore
---

Curate the **triage inbox** with the human: tickets filed by agents (verifier, `/harness:verify`, `/harness:arch-loop`, harness harvest)
that nobody has accepted yet. One ticket at a time, the human decides; this skill prepares the decision and carries it out.
Ticket shape and editing rules: `harness-resolve briefs/tickets.md`. Acceptance rubric: `harness-resolve briefs/triage-criteria.md`.
Operations (`list-triage`, `accept-triage`, `close-not-planned`, …): the adapter named in `.claude/harness.md` § Tracker
(`harness-resolve adapters/<tracker>.md`). No `.claude/harness.md` → say "run `/harness:init` first" and stop.

**Writes only to the tracker, only after the human's decision.** No application code, no tests; git is read-only. Labels, priority, assignee,
state, `## Status` and comments are written here; `## Problem`, `## Decision`, `## Acceptance criteria`, `## Touches` change only
through `/harness:ticket` (Refine). Temp files go to `<repo>/.user/triage/` and are removed at the end.

Arguments:
- **Ticket ids** → those, in the given order (each must be triage: label `triage`, or what the adapter calls triage; else say so, skip).
- **`--label <label>`** → only triage tickets that also carry it (e.g. `arch-loop`, `agent-harness`).
- **None** → the whole inbox.

## Step 0 — Inbox

- `list-triage` (filtered by `--label`). Empty → say "Triage inbox is empty." and stop.
- Order: priority (highest first, none last), then oldest. Print one table: `id · type · source (arch-loop | agent-harness | verifier |
  verify | human) · age · title`. Source = the label, else the `## Status`/`## Reference` line.
- More than one → ask once: `Go in order (Recommended)` / `Pick tickets` (follow-up with the ids) / `Only <source>`.

## Step 1 — Load & verify (per ticket)

- `read-ticket` with comments, `blockers-read`, and the `## Problem` of every ticket it references.
- Verify against the current code — read from `<repo>/.user/worktrees/_main` if it exists, else the repo; CodeGraph first when
  `.codegraph/` exists: every file:line in `## Problem`, what the code does today, whether it's already fixed (`git log` on the
  files since the ticket was filed, closed `search-tickets`, the forge's merged PRs).
- Duplicate check and collision check as `triage-criteria.md` §6 says.
- Score every criterion of `triage-criteria.md`: `pass` / `gap` / `fail` + one line of evidence. Derive the recommendation.

## Step 2 — Brief

≤ 15 lines, before any question:
```
<id> · <title> · <type> · from <source>, <age>
Problem: <one line> — today: <what the code does, file:line>
Scorecard:
  Valid ✓ · Clear problem ✓ · Reasoning ~ (no impact stated) · AC ✗ (none) · Scope ✓ (3 files, no plan-first) · Dup/collision ✓ · Labels ~ (no priority)
Recommendation: Refine, then accept at medium — <one-line why>
```
`✓` pass · `~` gap · `✗` fail.

## Step 3 — Interview

Ask what decides the ticket, via `AskUserQuestion` — **one decision per question**, question text stands alone (names the ticket),
2–4 options, the recommended one first with `(Recommended)` and its reason in the description, `preview` for code/criteria shapes.
- One question per `gap`/`fail`, in rubric order; skip what the evidence already settles.
- **Reasoning / value** (always, unless self-evident per the rubric): "Is <one-line problem> worth doing?" — `Now` / `Later (on hold)` /
  `Not worth it (close)`; follow up for the impact in the human's words if they pick Other.
- **Priority** (when missing): options from the adapter's scheme, recommended per the rubric.
- **Acceptance criteria gap**: propose the concrete criteria (in `preview`) — `Use these (Recommended)` / `Adjust` / `Skip AC`.
- Follow up until each answer is concrete. An answer that settles later questions → drop them. "Skip ticket" or "Stop" (via Other)
  at any point → Step 4 with `Skip` / end the run.
- Keep every answer, verbatim and resolved, for the handoff notes.

## Step 4 — Decide

Ask once: **"What do we do with <id>?"** — the recommendation first, then the others that apply:
- **Accept** — all criteria pass after the answers, no content change needed.
- **Refine, then accept** — content must change (problem, AC, touches, split).
- **Needs info** — a decision waits on someone/something.
- **Dismiss** — invalid, already fixed, or not worth it.
- **Duplicate of <id>** — only when Step 1 found one.
- (Skip via Other — nothing written.)

Then show the exact writes (labels, priority, assignee, state, `## Status`, comment) and ask: `Apply (Recommended)` / `Add a comment`
(take the text, appended to the decision comment) / `Adjust`.

## Step 5 — Apply

Re-read the ticket right before writing. Every path ends with one **decision comment**:
`**Triage (YYYY-MM-DD) · <decision>:** <1–3 lines: why, from the human's answers; priority + reason>` + the human's comment, if any.

- **Accept** — `set-priority`, fix the type label (`add-label`/`remove-label`), `## Status` = `Accepted in triage (YYYY-MM-DD) — ready for
  /harness:work.` (`edit-description`, own section only), `accept-triage`. `## Status` changed → no separate `Changed` comment; the
  decision comment names it.
- **Refine, then accept** — write the handoff notes to `<repo>/.user/triage/<id>.md`:
  ```
  # Triage handoff · <id>
  ## Scorecard
  <the Step 2 scorecard, updated with the answers>
  ## Verified evidence
  <file:line facts from Step 1; drift from what the ticket says>
  ## Decided
  - <question> → <answer> (<why>)
  ## Still open
  - <anything the human deferred to the refine step>
  ```
  Invoke `harness:ticket` via `Skill` with `<id> --triage-notes <abs path>`. It refines the content with the human and returns. Then
  re-read the ticket, re-score; all pass → apply **Accept** (no second confirmation — the human chose "then accept"); still a gap →
  ask: `Accept anyway` / `Needs info` / `Leave in triage`.
- **Needs info** — add `## Open questions` (the open decisions, with options) and `## Status` = `Triage — needs info: <who/what>`,
  `add-label needs-info`, keep `triage`. `Changed` comment per `tickets.md` (it names the decision). `/harness:ticket <id>` answers it;
  the next triage run accepts it.
- **Dismiss** — `close-not-planned`. Decision comment gives the reason (fixed by <PR>, evidence gone, not worth it: <why>).
- **Duplicate of <m>** — `close-duplicate` with `<m>`; `comment` on `<m>` with any evidence this ticket adds (one line + link).

Then the next ticket (Step 1). Remove `<repo>/.user/triage/` at the end.

## Report

One table: `id · title · decision · priority · note` (note = refined sections, the needs-info question, the dismiss reason, the
duplicate target). Then: triage tickets left (count, by source); `Skip`ped ids.

End with: **"Accepted tickets are assigned to you — `/harness:work` picks them up."** (none accepted: **"Nothing accepted."**)
