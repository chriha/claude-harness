# Triage criteria (/harness:triage)

A triage ticket is accepted only when **every** criterion passes. Score each one `pass` / `gap` (fixable now, with the human's
answers) / `fail` (blocks acceptance), with one line of evidence. Projects tighten or extend this file via an override.

## 1. Valid
- The evidence still holds on the current default branch: re-read every file:line in `## Problem` (CodeGraph first when
  `.codegraph/` exists). Moved code → find it; gone or already fixed → `fail` (recommend close, name the commit/PR if found).
- Bug → the cause is plausible from the code (not just a symptom); arch-loop → the invariant it cites exists and is still in force.

## 2. Clear problem
- `## Problem` says what happens vs. what should (feature: what's missing and for whom), with file:line evidence.
- One concern. Two unrelated problems → `gap` (split).

## 3. Reasoning / value
- **Why it matters**: impact (users, data, correctness, security, dev speed), who or what is affected, how often.
- **Cost of not doing it** — and of doing it (size, risk, migration). Recommend *now* / *later* (`on hold`) / *not worth it* (close).
- Agent-found tickets often lack this; it's the human's call — always ask unless the impact is self-evident (data loss, security).

## 4. Testable acceptance criteria
- `## Acceptance criteria` exists; each item is observable and testable, includes the tests that prove it (and, for refactors, the
  tests proving behaviour is unchanged). Only tests count as quality work: no style/lint/static-analysis items.
- Documented behaviour changes → an item to update the docs.

## 5. Scope
- `## Touches` lists the packages/dirs it changes (incl. tests, migrations, docs).
- Size estimate (files, rough lines) and the plan-first check (`briefs/implementer.md` "Gate first" + harness.md § Plan-first
  triggers). Plan-first is fine — the implementer plans it; flag it so the human knows.

## 6. No duplicate / collision
- `search-tickets` (open and closed) on title and Touches keywords: an open ticket covering it → `fail` (recommend duplicate-of).
- Collision check (`tickets.md`): in-flight or plan-approved overlap → `gap` (recommend blocked-by or relate).

## 7. Labels & priority
- Exactly one type label (`bug` / `improvement` / `feature`) that matches the problem.
- A priority (adapter scheme). Agents file without one; recommend one with a reason: urgent = data loss/security/outage;
  high = user-facing bug with no workaround; medium = default for bugs and real debt; low = nice to have. Arch-loop tickets cap at medium.

## Recommendation
- All pass → **Accept**.
- Only gaps in 2, 4, 5 → **Refine** (via `/harness:ticket`), then accept.
- Gap in 3 the human can't answer now, or a decision that needs someone else → **Needs info**.
- Fail in 1 or 6, or 3 judged not worth it → **Dismiss** / **Duplicate**.
