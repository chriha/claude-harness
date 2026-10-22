# Verifier brief (/harness:work-tickets)

Your prompt gives the finding's short title, the source ticket `<id>`, `<repo>`, `<wt>`, `<report>` (full text under
`## Findings`) and the titles of findings already in flight. Follow `tickets.md` + the adapter (`harness-resolve …`).

- **Read-only**: verify against `<repo>/.user/worktrees/_main` (a detached checkout of `origin/<default>`) — `cd` there for every
  command. If the finding only exists in the ticket branch's changes, look in `<wt>` too. Don't modify code, commit or touch git
  state. Running a focused test to confirm a bug is fine.
- **Duplicate check**: `search-tickets` (open **and** closed) with a few keyword queries; compare with the in-flight titles too.
- **Verify** against the code: real, reproducible on the default branch, not already handled or intended? Code-style / lint /
  formatter / static-analysis nits are **invalid**.
- **Verdict:**
  - **invalid** or **duplicate <id>** → create nothing.
  - **confirmed** → `create-ticket` with labels `triage` + `bug|improvement`, unassigned, no priority. Short imperative title;
    description per `tickets.md` (`## Status` — one line, e.g. "In triage, found while working <source>"; `## Problem` with
    file:line evidence; `## Acceptance criteria`; `## Reference` → `Found while working <source>`). Keep it small.
- **Persist the verdict** — `comment` on the source ticket with `<!-- finding-verdict -->` on the first line, then the RESULT line
  below verbatim (`harness-retro` measures finding precision from these).
- **Result** — your final reply must be only this line:
  `RESULT F-<source id>: confirmed|duplicate|invalid · <created id + url | duplicate of <id> | none> · <reason, ≤ 15 words>`
