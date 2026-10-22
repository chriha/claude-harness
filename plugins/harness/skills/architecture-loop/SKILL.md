---
name: architecture-loop
description: Detect architecture drift — scan domains for rule violations, triage signals into tickets, write acceptance criteria, optionally hand them to /harness:work-tickets
argument-hint: "[domain-slug | path] [--budget N] [--handoff]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, AskUserQuestion, Bash(grep:*), Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(mkdir:*), Bash(rm:*), Bash(harness-*:*), Bash(gh issue:*), Bash(gh label:*), mcp__codegraph__codegraph_explore
---

Run the architecture loop. **Signals and tickets are tickets of this repo's tracker** (adapter: `harness-resolve adapters/<tracker>.md`),
each carrying the **`arch-loop`** label so the loop finds its own work. Shape and editing rules: `harness-resolve briefs/tickets.md`.
Pipeline: `signal → ticket → PR → outcome`.

**Domains registry** (audit scope + invariants per area): `harness-resolve architecture-domains.md` — i.e. the project's
`<repo>/.claude/harness/architecture-domains.md`. **Missing** → derive domains from `.claude/rules/*.md` (one domain per rule file:
`owns_paths` from its `paths:` frontmatter, `invariants` = that file) and offer to write the registry at the end. Format per domain:
`## <slug>` then bullets `status: active|paused`, `owns_paths: \`glob\`, …`, `invariants: \`.claude/rules/x.md\`, \`<test path>\`, …`, optional
`targets:` (below).

**Everything this skill creates is labeled `triage` and unassigned — never further.** It detects and plans; a **human** curates the
triage inbox (removes `triage`, assigns to themself) and only then `/harness:work-tickets` picks it up. The one exception is `--handoff` (Step 4).

| Loop concept | Ticket | Set by |
|--------------|--------|--------|
| signal (open) | open, labels `arch-loop` + `triage`; `## Reference` names the domain | this skill |
| signal (dismissed) | closed *not planned* (or duplicate, linked) + one-line reason `comment` | this skill |
| ticket (planned, awaiting review) | `arch-loop` + `triage` + `improvement`, has `## Problem` + `## Acceptance criteria` | this skill |
| ticket (accepted) | `triage` removed, assigned to the human | **a human** (or `--handoff`) |
| in progress → PR → merged | per adapter (`in-flight`, closing keyword) | `/harness:work-tickets`; no loop agent sets these |
| outcome (decision record) | `## Outcome` in the description | the implementer, on `done` |

**Priority/severity is capped at medium.** Arch-loop tickets are tech debt, never bugs: no `bug` label, no urgent/high priority; signal
severity `low` → low, `medium`/`high` → medium.

**Detects and plans only. Never writes application code, never closes tickets other than dismissed signals, never removes `triage`
(except `--handoff`), never touches git or PRs.** Hard prohibition: no `git add/commit/push/switch -c`, no PR commands. Temp body files go
to `.user/` (gitignored) and are removed after use. **No git worktree** — nothing to isolate or commit. All tools work; call a tool only
with a clear purpose.

Work the scope until there is no new drift to file **within the budget** and every planned ticket has its acceptance criteria. Then stop.

Arguments (all optional): first a **domain slug** or a **bare path**; flags may follow.
- **Slug** → that domain's `owns_paths` + `invariants`. **Path** → ad-hoc scan: `owns_paths` = path, `invariants` = every
  `.claude/rules/*.md` whose `paths:` matches (none → all). **Omitted** → every `active` domain.
- **`--budget N`** (default `5`) → file at most N **new** signals this run, highest severity first; the report states how many were left
  out and their severities. Signals that dedupe into existing tickets don't count.
- **`--handoff`** → skip the human gate (Step 4).

## Domain targets (optional)

A domain may carry numeric `targets`, one `name: <comparator> <limit>` (`<=` or `=`) per line, each a measurable count over its
`owns_paths` (e.g. `arch_test_exclusions: = 0`, `cross_module_imports: = 0`). Humans add them; the loop only measures and reports.

## Step 0 — Load state

- Read the registry (above). Ensure labels exist (`create-label`, idempotent): `arch-loop`, `triage`, `improvement`.
- Resolve the argument; for an ad-hoc path that yields real signals, offer to add a domain to the registry (write the project override file).
- **Measure targets** per in-scope domain (grep/codegraph; count only, no fixing). Keep value vs. target for the report.
- **List existing loop tickets** (`search-tickets` label `arch-loop`, open **and** recently closed) so you dedupe: note open signals
  (`triage`), accepted/in-flight ones, dismissed ones, and the domain each names. Never re-file a match.

## Step 1 — Scan (produce signals)

Audit each in-scope domain's `owns_paths` against its `invariants`, cheapest first:
- **Architecture tests** — harness.md `arch_test:` command (key, optional), run once per run. A failure is a signal, verbatim.
- **Rules** named in `invariants` (`.claude/rules/*`, `CLAUDE.md`) — check the code obeys them; code that predates a rule and is
  excluded from the strict tests is the highest-signal drift.
- **Burndown** — harness.md `## Ratchets` / baseline or suppression entries for in-scope paths now trivially removable; cluster per
  file/namespace into one signal.
- **Dead markers** — `TODO refactor`-style markers, commented-out architecture rules, code a change would let you re-enable.
- **CodeGraph** (`codegraph_explore`, only if `.codegraph/` exists) for layering/dependency/dynamic-dispatch questions grep can't answer.

For each **new, non-duplicate** drift (up to the budget; rank the rest by severity and count them), `create-ticket`: labels `arch-loop` +
`triage` + `improvement`, unassigned. Title = the one-line symptom. Body in the `tickets.md` shape:
- `## Status` — `Triage — open arch-loop signal`.
- `## Problem` — observation, evidence (file:line, test names, commands), the invariant at risk (link the rule).
- `## Reference` — `arch-loop signal · domain: \`<slug>\` (or the ad-hoc path) · severity: low|medium`; `Related: <id>`.

## Step 2 — Triage (signals → tickets)

Review **all** open signals. Everything stays `triage`.
- **Real, related signals → a ticket.** Enrich one signal in place, or cluster several: pick/create one ticket, fold each signal's
  evidence into its `## Problem`, close the others as duplicate (`comment` "Duplicate of <id>" + close *not planned*). The ticket's
  `## Reference` keeps the domain line and lists the folded signals. Retitle (short, imperative) when it now covers more.
- **Noise / false positive / accepted legacy** → close *not planned* with a one-line `comment`.

## Step 3 — Plan (acceptance criteria)

For **every** planned ticket add `## Acceptance criteria` between `## Problem` and `## Reference` (set `## Status`: `Triage — planned,
awaiting review`): `- [ ]` lines, one testable condition each, incl. the tests proving behaviour is unchanged. Where compliance makes an
architecture-test exclusion or baseline entry removable, add an item to remove it — the durable win. Add `## Touches`. Large/structural
tickets are fine — the implementer's plan-first gate splits them into PRs. Leave everything `triage`.

## Step 4 — Hand over & report

Summarize with ids (`<id>` + one line), not bodies: domains scanned; new signals (id, severity); signals dismissed; tickets planned;
**skipped over budget** (`N more not filed`, severities; omit if none); **targets** per domain (value vs. target, met or not; omit if none);
tickets now `triage` awaiting acceptance (id, priority, one line, url).

**Default:** stop. End with: **"Filed as `triage`. Review the `arch-loop` + `triage` tickets, remove `triage` and assign accepted ones to
yourself — `/harness:work-tickets` picks them up."** Do not run work-tickets, remove `triage`, or close tickets yourself.

**`--handoff`:** for each planned ticket `remove-label triage`, assign to me, then invoke `/harness:work-tickets <id> <id> …` in this session
(`Skill`). It gates, plans or implements each ticket and opens draft PRs — handing off skips none of *its* checkpoints. Relay its report.
