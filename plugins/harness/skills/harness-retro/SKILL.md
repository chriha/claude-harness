---
name: harness-retro
description: Measure the agent harness KPIs over a window, append a row to the metrics doc and print the delta
argument-hint: "[window-days, default 14]"
disable-model-invocation: true
allowed-tools: Read, Grep, Edit, Write, Bash(git fetch:*), Bash(git show:*), Bash(git log:*), Bash(git grep:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh issue list:*), Bash(gh issue view:*), Bash(gh api:*), Bash(jq:*), Bash(date:*), Bash(harness-*:*)
---

Measure whether the harness works. **Read-only on code, git, tracker and error monitoring** — the only write is one appended row in the
metrics doc: `harness-config key metrics_doc` (default `<repo>/docs/harness-metrics.md`; created on the first run).
Operations (`list-prs`, `view-pr`, `review-threads`, …) come from the adapter (`harness-resolve adapters/<forge>.md`); shape of
tickets/verdicts from `harness-resolve briefs/tickets.md`.

Argument (optional): window in days, default `14`. `$FROM` = now − window, `$TO` = now (`date -u`).

An **agent PR** is a merged PR whose commits carry the `Co-Authored-By: Claude` trailer. Candidates: merged PRs in the window
(`list-prs` state merged, filter `mergedAt`); confirm the trailer per PR from its commits. A **human-authored commit** is one without
that trailer whose author is a person.

## KPIs

1. **First-pass acceptance** — agent PRs merged with **no human-authored commit after the PR was opened**, ÷ all agent PRs. `n/N` + %.
2. **Review threads per PR** — human discussions per agent PR (`review-threads`: threads whose first comment is by a human, not the
   agent or a bot). Mean and median.
3. **Lead time** — per agent PR, ticket *ready* → `mergedAt`. *Ready* = per adapter (GitHub: the timeline event removing `triage`
   / adding the assignee, else the issue's `createdAt`). Median and p90 in hours. Skip PRs without a ticket.
4. **Outcome split** — tickets updated in the window: count `done / partial / blocked / planned / needs-info` from the `## Status`
   line or, failing that, the latest `Changed` comment. Open a ticket only when the list output doesn't show it.
5. **Finding precision** — `confirmed / (confirmed + duplicate + invalid)` over verifier verdicts in the window: comments starting
   `<!-- finding-verdict -->` on the source tickets of KPI 4. Report the three counts and the ratio. None yet → `n/a`.
6. **Entropy ratchets on `origin/<default>`** (`git fetch origin <default>` first; read via `git show`/`git grep`, never the working tree):
   harness.md `## Ratchets`, one `name: command` per line, each printing a number (e.g. baseline-entry counts, suppression counts,
   arch-test exclusions). Run each against the fetched ref (a command may use `origin/<default>:` paths). No section → skip.
7. **Post-merge breakage** — *only when harness.md has `sentry: true`*: agent PRs with ≥1 Sentry issue (first seen in the window)
   whose suspect commit belongs to them (their commit SHAs incl. merge/squash SHA), ÷ all agent PRs; count a PR once. Use the `sentry`
   MCP tools (`find_organizations`/`find_projects`, `search_issues`, `get_sentry_resource`). Unreachable / no commit data → `n/a`, never `0`.

### Guardrail value

Local data only: `<repo>/.user/reports/archive/issue-*.md` (archived implementer reports) whose date suffix is in the window, plus
the reports in `<repo>/.user/reports/` and the run logs in `<repo>/.user/runs/` (covers runs from this machine only). Read with Read/Grep.

8. **Reviewer-source yield** — from each report's `## Review` lines `- [<source>] … — fixed|out of scope|open`: per source (`rules`,
   `test-quality`, `code-review`, `intent`) the findings and the fixed findings. Untagged old-format lines are skipped.
9. **Red-check exits** — count of the `red-check: exit <n>` lines in the reports' `## Tests`, per exit code (0–5).
10. **Failure classes** — counts per class once failure classes are recorded in reports/run logs (ticket #11); until then `n/a`.
11. **Consults** — from each report's `## Review` lines `- consult: <role> · <model> · <trigger> · <n>k tokens`: the count and the
    summed tokens per model (`haiku`, `sonnet`, `opus`), written `n/Nk` each, plus the count of `stuck-fix` consults. Reports
    without consult lines (older format) are skipped.

No archive/report data in the window → KPIs 8–11 are `n/a`, never `0`. A source with reports but no tagged lines is `n/a` too.

A KPI with no data in the window is `n/a`, never `0`.

## Record

1. Read the metrics doc. Missing → create it with a one-line header and the table header below (+ one column per ratchet; add a
   column when a ratchet is new — older rows read `n/a` for it).
2. Parse the **last** table row as the previous row (for the delta).
3. Append one row, keeping the rest of the document intact:

```
| date | window | agent PRs | first-pass | threads/PR | lead time p50/p90 (h) | done/partial/blocked/planned/needs-info | finding precision | findings/fixed rules | findings/fixed test-quality | findings/fixed code-review | findings/fixed intent | red-check exits (0/1/2/3/4/5) | failure classes | consults haiku/sonnet/opus (n/Nk) · stuck-fix | <ratchet…> | post-merge breakage |
```
(omit the breakage column unless `sentry: true`; older rows without the guardrail columns read `n/a` for them — add the columns to the header when missing)

4. Print the new row and a delta line per KPI against the previous row (`+n`, `-n` or `n/a`), then one line naming the largest
   regression, if any. First run: say there is no previous row.
5. **Prune candidates** — after the delta lines: for each reviewer source whose fixed-findings count is `0` in this row and the
   two rows before it (3 rows, this one included; every one of the three must have data, not `n/a`), print
   `candidate to drop: <source>`. Fewer than 3 rows → print nothing. Report only; change nothing.

Commit nothing — the doc change is left for the human.
