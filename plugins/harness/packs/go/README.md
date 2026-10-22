# Go pack

Defaults for Go repos (derived from `lanes`): `harness.md` (commands, red-check, plan-first triggers, self-check, test conventions)
and a `settings.json` allow-list fragment. No rules directory — Go conventions live in the project's `CLAUDE.md`.

`/harness:init` merges `harness.md` into `<repo>/.claude/harness.md` and the allow-list into `<repo>/.claude/settings.json`
once; both are project-owned afterwards. Assumes a `make test` target (`go vet ./... && go test ./...`); adjust `## Commands` if not.
