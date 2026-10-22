---
name: work-on-comments
description: Fetch the open review comments on this branch's PR, verify each against the code, fix or answer them systematically, and harvest the lessons into guardrails
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Agent, AskUserQuestion, Bash(harness-*:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git rev-parse:*), Bash(jq:*), Bash(gh pr:*), Bash(gh api:*), Bash(gh issue:*), mcp__codegraph__codegraph_explore
---

Operations (`pr-of-branch`, `review-threads`, `reply-to-comment`, `resolve-thread`, …) come from the forge adapter named in
`.claude/harness.md` § Tracker (`harness-resolve adapters/<name>.md`). Project checks: harness.md § Commands. `<default>` = default branch.

**Step 1 — Fetch & categorize**

In parallel: current branch (`git branch --show-current`) and the branch diff (`git diff <default>...HEAD`). Then:
- `pr-of-branch` → open PR; none → say so and stop.
- `review-threads` (unresolved, with resolution state; page past 100) and general PR comments/reviews. A human comment asking for a change is open; ignore approvals and pure acknowledgements.

Keep only **unresolved** threads with human-authored notes (not the PR author replying to themselves, no bots/system notes). Keep outdated threads but say so.
No open comments → say so and stop.

**Verify first.** Give every comment a verdict by reading the code it references (and callers where the claim depends on them): one sonnet sub-agent per
comment in parallel (opus for design, concurrency, security or data-loss claims), each returning a verdict with file:line evidence:
✅ **Valid** · ◐ **Partly valid** (say which part) · ❌ **Invalid** (code contradicts the claim) · ❓ **Unverifiable**.
Invalid/Unverifiable never trigger a code change: → 💬 Clarify with a drafted reply (cite evidence, or what's needed to verify).

Group the rest: 🟢 **Quick fix** (trivial, low risk; fixer `sonnet`) · 🔴 **Complex** (design/refactor, or Partly valid/disputed; fixer `opus`) · 💬 **Clarify**.
Then scan the diff for the *same class of issues* the reviewers flagged but missed elsewhere; add them as self-identified items.

**Step 2 — Overview + quick-fix plan.** Present: review status in a line; the categorized list (file:line, verdict + evidence, model); one sentence per quick fix;
the drafted reply for each Invalid/Unverifiable. Ask: "Shall I work on all the quick fixes?"

**Step 3 — Quick fixes (after approval).** Each in a `sonnet` sub-agent, one focused Conventional Commit per fix (`harness-resolve briefs/git-rules.md`), harness.md
`test`, `static`, `format` clean before each commit. Report when done. Nothing is pushed and no thread is resolved or replied to without the human saying so.

**Step 4 — Complex tasks, one at a time.** `opus` sub-agent (or the session if already opus): read all relevant code first, present 1–3 approaches with
trade-offs and a recommendation. Wait for a choice, implement, summarize, wait for confirmation before the next.

**Step 5 — Clarifications, one at a time.** Quote the comment and verdict, give context (what the code does, symbols with line numbers), show the drafted reply and
ask how to respond. `reply-to-comment` / `resolve-thread` only on request. Continue until all are addressed.

**Step 6 — Harvest.** Run the harness harvest (`harness-resolve briefs/tickets.md`, "Harness harvest") over every comment resolved this session, incl. the self-identified
ones. Skip if none were resolved.
