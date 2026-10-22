# Ticket shape (shared by all harness skills and briefs)

Platform commands live in the **adapter** (`harness-resolve adapters/<tracker>.md`, tracker from harness.md § Tracker).
Below, operations are named in `code style` — look them up there. Tickets are referenced as the adapter says (`#nnn`, `EQD-nnn`, …).
`/harness:work-tickets` works the open tickets **assigned to me**. A PR closes its ticket through the adapter's closing
keyword — **no agent ever closes a ticket or changes its assignee/status.**

Labels (names per adapter) that steer the pipeline:

| Label | Means | Who removes it |
|-------|-------|----------------|
| `on hold`, `ready-for-human` | not for agents | human |
| `needs-info` | `## Open questions` in the description | `/harness:ticket <id>`, after answering |
| `planning` | a `## Plan` awaits approval | human — removing it approves the plan |

Type labels: `bug`, `feature`, `improvement`. Priority: adapter scheme (none sorts last). Other: `triage` (found by an
agent, not yet accepted), `agent-harness`.

**Body (description)** — the full, **current** state of the ticket, rewritten in place (the tracker keeps the edit
history). Sections, in this order, omitting empty optional ones:
- `## Status` — one or two lines: where the ticket stands, next step, who it waits on, the PR url.
- `## Problem` — what happens vs. what should, with file:line evidence; for features: what's missing and why.
- `## Decision` — optional; the agreed answers, concrete. Opens with an `Understanding:` bullet (problem restated in
  2–3 lines, confirmed by the human); each decision bullet names the alternatives rejected and why.
- `## Open questions` — optional; questions with options. When answered, the human or `/harness:ticket` folds the answer
  into `## Decision` and removes the question; an autonomous agent marks it `→ answered (see comment)`.
- `## Acceptance criteria` — checklist, each item testable.
- `## Touches` — packages, types, dirs it changes, one per line.
- `## Plan` — optional; the implementer's planning format (`briefs/implementer.md`) with the `<!-- work-tickets plan -->`
  marker inside. Each shipped slice is marked in place with its PR url.
- `## Outcome` — optional; the decision record.
- `## Reference` — optional; docs, `Related: <id>`.

A ticket without a clear problem and testable acceptance criteria is not ready.

**Requirements are human-owned.** On an existing ticket, `## Problem`, `## Decision` and `## Acceptance criteria` change
only through an interactive skill whose draft the human approves (`ticket`, `answer-tickets`). Autonomous
agents (triager, implementer, verifier) write only `## Status`, `## Open questions`, `## Touches`, `## Plan`, `## Outcome`.
If a requirement looks wrong, adjust the solution or go **needs-info** with an open question; never fit the requirement to
the solution. Creating a new ticket writes all sections.

**Every writer updates `## Status`**: the filing skill, the triager on needs-info, the implementer on planned/partial/blocked/done.

**Editing:** `edit-description` — change **only your own sections**, keep every other character intact, re-read right
before writing. Only interactive skills may rewrite the human-owned sections.

**Plan-approved** = the description has `## Plan` (or, on an unfolded old ticket, a comment starting with
`<!-- work-tickets plan -->`) and the ticket has **no** `planning` label. Implement its **next unshipped PR slice** only.

**`Changed` comment** — every description change is followed by one `comment`:
`**Changed (YYYY-MM-DD) · <sections touched>:** <1–3 lines: what and why>`. A pointer, not a change log.

**Fold on touch** — the first writer to touch an old-format ticket (state in comments, an old plan comment,
`## Update (…)` comments) folds that into the living description, then posts one `Changed` comment. An autonomous agent
folds only into its own sections; what belongs in a human-owned section stays in its comment (still read as context).

**Blockers** are tracker dependencies (`blockers-read` / `blockers-add`); "related" is `Related: <id>` under `## Reference`.
**Every PR needs a ticket:** its description contains the closing keyword, its branch/title carries the id as the adapter says.

## In-flight work & the collision check

**In-flight** = per adapter (`in-flight`). There is no `in-flight` label.

Direction of a migration never goes into code or docs while it is in flight. The PR slice that lands the new path on
the default branch adds a **freeze test** on the legacy side (fails when the legacy code gains new users); the test goes
when the legacy side goes.

**Collision check** — bounded; never iterate over all open tickets:
1. `in-flight` tickets.
2. 2–3 `search-tickets` on the ticket's `## Touches` entries (none → keywords from title/problem). Also catches tickets with
   an approved plan and no PR yet.
3. Open a ticket in full (incl. `## Plan`) only when its title or a hit suggests it touches the same code. Ignore the
   ticket itself and tickets already linked to it — that overlap was decided.

A hit = a ticket that is in-flight or plan-approved and touches the same code. What happens on a hit is up to the caller.

## Harness harvest (`work-on-comments`, `local-code-review --fix`)

Turns review corrections into guardrails. Input: the comments resolved / findings applied in this run.

1. **Classify** each item, print a table `link (or file:line) -> class -> one-line reason`:
   - **mechanizable** — could be a test, linter/static-analysis rule or CI check.
   - **instructable** — a missing or unclear line in `CLAUDE.md`, `.claude/rules/*`, `.claude/harness.md` or a brief.
   - **judgment** — nothing to change; creates nothing.
2. **Group** mechanizable/instructable items into one pattern each. No patterns → stop. Stable lowercase key
   `<guardrail-type>:<area>` (e.g. `mechanizable:session-layering`); reuse the key of an existing `agent-harness` ticket on match.
3. **Dedupe:** `harness-issues` by key (triage ones included); if nothing, retry with the pattern keywords. A duplicate gets a
   `comment` with the new evidence, not a new ticket.
4. **Confirm once:** one `AskUserQuestion` listing every new ticket and every duplicate comment. File nothing without approval.
5. **File** each approved pattern: `create-ticket` with labels `agent-harness` + `triage`, unassigned, no priority. Body:
   `Key: <key>`, `## Status` (triage, filed from review), `## Problem` (evidence, file:line), the proposed guardrail (which
   rule file / test / brief), `## Acceptance criteria`.
