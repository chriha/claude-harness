---
name: verify
description: Verify locally, end to end, that the branch's change (or a ticket's acceptance criteria) works, and report evidence per criterion
argument-hint: "[ticket-id] [--allow-external-apis]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Agent, AskUserQuestion, Bash(git branch:*), Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(grep:*), Bash(cat:*), Bash(ls:*), Bash(curl:*), Bash(harness-*:*), Bash(gh issue:*), mcp__codegraph__codegraph_explore
---

Standalone local verification: proves the **current branch's** change works by driving the real flow, and reports evidence per
acceptance criterion. Writes no code, opens no PR. Run inside the checkout/worktree to verify (`<wt>`). Also the procedure the
implementer brief follows before opening a PR (unattended there — see Step 4).

Project config: harness.md `## Verify` (`harness-config section Verify`). **No `## Verify` section → say so and stop** (nothing to
drive; suggest adding one). Keys it may contain, one per line:

| Key | Meaning |
|-----|---------|
| `env_file:` | file holding the runtime settings to preflight (default `.env`); `none` skips preflight |
| `allow:` | repeatable `KEY=<regex>`: the key's value must match, else **abort**. Missing key = ignored. e.g. `APP_ENV=^(local\|testing)$`, `DB_HOST=^(localhost\|127\.0\.0\.1\|db)$`, `APP_URL=\.local$\|localhost` |
| `tests:` | command for a focused test run, `{filter}` placeholder (never the whole suite) |
| `cli:` | how to run a CLI/console command for this project (prefix/wrapper, e.g. a container exec) |
| `http:` | base URL of the local app, or `none` |
| `ui:` | how to drive the UI (e.g. `playwright`), or `none` |
| `serves:` | `checkout` (HTTP/UI always hit the main checkout, so in a worktree they are `skipped`) or `any` |
| `external:` | `ask` (default) \| `deny` \| `allow` — policy for calls to external providers (anything not on the local stack) |
| `start:` | how to start the local stack when `http` is unreachable (shown to the user, never run) |

Argument:
- `<ticket-id>` → verify that ticket's `## Acceptance criteria` (`read-ticket`). Omitted → the id in the branch name (adapter rule);
  none → derive criteria from the diff (`git diff <default>...HEAD`) and commits.
- `--allow-external-apis` → pre-approves every external provider (same as `external: allow`).

## Step 1 — Preflight (before running anything)

For each `allow:` rule read `env_file` and **abort** with a message naming the offending key and value when a present key does not
match. **No override flag.** An abort runs nothing; report status is `aborted` with the reason.

## Step 2 — Drive the real flow

Classify each criterion and prove it with the real thing, no bypass:
- **Tests** — `tests:` with `{filter}` = the relevant test names; the test must invoke the real code, not a mock of it. Never the whole suite.
- **CLI** — run via `cli:`; check output and effects.
- **HTTP** — `curl` the `http:` base; record status and body. Unreachable → ask the user to start the stack (`start:`). In a worktree
  (`git rev-parse --git-dir` ≠ `--git-common-dir`) with `serves: checkout` mark the step `skipped` ("stack serves the main checkout, not <wt>") — never passed.
- **UI** — drive via `ui:`; keep a screenshot path. Same worktree rule as HTTP.

**External APIs.** Before the **first** real call to each external provider, per `external:`: `ask` → one `AskUserQuestion`
(header = provider) *"Call <provider> for real?"* Yes / No; `deny` → skip; `allow` or `--allow-external-apis` → go. A declined
provider → every step that needs it is `skipped` — never faked, mocked or guessed. Unattended runs never ask: treat `ask` as `deny`.

## Step 3 — Report

One table, then a status line:

| Criterion | Result (pass / fail / skipped) | Evidence |
|-----------|--------------------------------|----------|

Evidence is concrete: test names + result line, command output, HTTP status + body excerpt, screenshot path, or the reason a step
was skipped. Overall: `aborted` (preflight), `failed` (any fail), `passed` (no fail; skipped allowed but listed), never `passed`
when nothing ran. Always print the skipped count (`passed, 2 skipped`).

## Step 4 — Issues

If any criterion failed (or you noticed a defect), ask **once** with `AskUserQuestion`:
- **Fix issues** — fix them, then re-run Steps 2–3.
- **File as tickets** — one `create-ticket` per issue (labels `triage` + `bug`, `Related: <source id>` under `## Reference`): `## Status`
  (triage, filed from verify), `## Problem` with the evidence, `## Acceptance criteria`.
- **Ignore** — stop.

Not asked when called from the implementer (unattended): return the report as-is, no fix loop, no tickets.
