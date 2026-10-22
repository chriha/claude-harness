# Go pack defaults
<!-- Merged into <repo>/.claude/harness.md by /harness:init. Edit the project copy, not this file. Section names per CONVENTIONS.md. -->

## Commands
- test: `make test`   <!-- go vet ./... && go test ./... — what CI runs; no Makefile: `go vet ./... && go test ./...` -->
- test-affected: `go test -count=1 {packages}`
- static: `go vet ./...`
- format: `gofmt -l .`   <!-- must print nothing; fix only changed files: `gofmt -w <files>` -->
- build: `go build ./...`
- setup-worktree:    <!-- none; bin/ is gitignored and built per worktree -->

## Scripts
- red_check_test_cmd: `go test -count=1`   <!-- red-check appends the packages of the changed test files -->
- test_file_glob: `**/*_test.go`
- exclude_from_size: `:(exclude,glob)**/*_test.go` `:!go.sum`

## Branch & commits
- branch types: `fix|feature|refactor|chore`; branch: `<type>/<ticket>-<slug>`, lowercase, ≤ 60 chars after the type
- commit types: `feat|fix|docs|style|refactor|perf|test|chore|ci`; scope optional, one word; subject ≤ 72 chars total

## Plan-first triggers
Extend the generic gate in `briefs/implementer.md`. Plan first when any of these hold:
- blast radius: an exported function with many callers, a change to a core interface, a change in a UI/event-loop message flow
- hard to undo: config schema, on-disk cache/history/state format, a documented CLI flag or key binding, an external JSON/wire contract
- multiple real designs (new package vs existing, sync vs background work)
- needs sequencing (several PRs, deprecation period)
- data loss involved (deleting files, closing sessions)

## Self-check
Before every commit — none of:
- invented functions or methods (verify they exist)
- swallowed errors or `_ =` added to silence one
- a helper duplicating an existing one (grep first)
- a goroutine without a way to stop it; a data race on shared state (go through the owning loop/messages)
- shelling out with an unquoted/unvalidated string
- `//nolint` or skipped tests to make a check pass
- `go get` / `go mod tidy` / hand-edited `go.mod`/`go.sum` (a dependency change is an open question)

## Test conventions
- Table-driven; goal-first (specify behavior, edge cases, error paths), one behavior per test, assert behavior not internals.
- Deterministic and independent: `t.TempDir()`, `t.Setenv`, `t.Helper()`; no `time.Sleep`, real clock, network, or the user's real config dir / services without a fake; no package-level shared mutable state or order dependence.
- Never touch the user's real environment (tmux server, config dir, network).
- Unit vs integration level should fit the behavior under test; cover error paths and boundary values when the diff adds logic that warrants them.

## Never
- Change dependencies without approval.
- Add `//nolint`, skip tests, or loosen a check to get green.
- Run `gofmt` over the whole tree in a feature diff — format only the files you changed.
