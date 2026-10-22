# Laravel pack defaults
<!-- Merged into <repo>/.claude/harness.md by /harness:init. Edit the project copy, not this file. Section names per CONVENTIONS.md. -->

## Commands
- test: `php artisan test --compact --parallel`
- test-affected: `php artisan test --compact {files}`   <!-- files or `--filter=<name>` -->
- static: `composer test:static-analysis`   <!-- PHPStan/Larastan; fallback: `vendor/bin/phpstan analyse --memory-limit=1G` -->
- format: `vendor/bin/pint --test`   <!-- check only; auto-fix: `composer lint` or `vendor/bin/pint <files>` -->
- build: `npm run build`   <!-- only when the ticket touches resources/js; a fresh worktree needs it before browser tests -->
- setup-worktree: `composer install --no-interaction && npm ci`   <!-- project may replace with a script that clones vendor/ (APFS `cp -cR`) and links node_modules -->
- full-gate: `composer test`   <!-- everything CI runs; use `composer test:lint`, `composer test:types`, `composer test:unit` to rerun a single gate -->

## Scripts
- red_check_test_cmd: `php artisan test --compact`   <!-- red-check appends the changed test files -->
- test_file_glob: `**/*Test.php`
- exclude_from_size: `:(exclude,glob)**/tests/**` `:!composer.lock` `:!package-lock.json` `:!*.generated.*`

## Branch & commits
- branch types: `fix|feature|refactor|chore`; branch: `<type>/<ticket>-<slug>`, lowercase, ≤ 60 chars after the type
- commit types: `feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert`; scope optional, one word; subject ≤ 72 chars
- Conventional Commits are enforced by `githooks/commit-msg` (semantic-release friendly); put the ticket id per tracker adapter.

## Plan-first triggers
Extend the generic gate in `briefs/implementer.md`. Plan first when any of these hold:
- a migration on a large table, a data backfill or a column type/nullability change
- a change to a public API contract (response shape, status codes, auth) or to a queue/job payload shape
- cross-cutting change: a shared base class/trait/Facade, event → listener chains, a new Workflow, service container bindings
- search-index mapping change or anything deploy-order dependent (expand → migrate → contract)
- new package, new directory under `app/`, or a choice between Action / Workflow / Service with no sibling to copy
- money, auth/authorization or data deletion involved

## Self-check
Before every commit — none of:
- invented methods, `__call`/Facade calls that don't exist (verify them)
- a broad `catch`, swallowed exception, or `?->` added just to silence an error
- a helper that duplicates an existing one (grep first)
- mass-assignment widening (`$guarded = []`), `authorize()` returning `true` blindly, raw SQL / unscoped queries
- `->save()`/`DB::` inside a Workflow, a job dispatched from an Action, a Service that writes (see `.claude/rules/`)
- `@phpstan-ignore`, widened types or `mixed` to silence static analysis; new PHPStan baseline or arch-test exemption entries
- `composer require/update/remove` (a dependency change is an open question)

## Test conventions
- Pest, test-first, red before green; test at seams (Action `handle()`, Query result, Service method, HTTP endpoint) — see `.claude/rules/testing.md`.
- Real test DB (`RefreshDatabase` + factories); mock only boundaries (HTTP, time, filesystem, queue/mail/event fakes).
- No assertion-free tests, no asserting a mock's own return value, no mocking the class under test, no top-level named functions in test files.
- Expected values come from an independent source, never recomputed like the code does.
- Architecture rules are Pest arch tests in `tests/Architecture/`.
- HTTP endpoints: feature test for happy + failure paths (+ OpenAPI conformance test where the project has the tooling).

## Never
- Change dependencies without approval; create base folders under `app/` without approval.
- Add PHPStan baseline entries or arch-test exemptions to make a change pass.
- Create docs/verification scripts/tinker runs when a test proves the behavior.
- Commit on `main` (the pre-commit hook blocks it).
