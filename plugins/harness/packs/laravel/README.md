# Laravel pack

Starting point for Laravel + Pest + Pint + PHPStan projects. Best-of of five projects (laravel-starter-kit's lean base,
path-to-war/eqdata's stricter Action/Workflow/Service/events rules and naming table, eqdata's testing rule).

| Path | What |
|------|------|
| `rules/*.md` | Path-scoped rules (`paths:` frontmatter) for `.claude/rules/`: actions, architecture, artisan-commands, controllers-routing, data-objects, database-eloquent, events, php-standards, query-classes, services, testing, validation, workflows, api-standards (opt-in) |
| `harness.md` | Defaults for `.claude/harness.md`: commands, red-check, branch/commit rules, plan-first triggers, self-check, test conventions, never |
| `settings.json` | `permissions.allow` fragment (valid `Bash(cmd:*)` entries only) |
| `githooks/` | `pre-commit` (blocks commits on main, Pint + optional PHPCBF/PHPCS), `commit-msg` (Conventional Commits), `setup-hooks.sh` |

## How /harness:init uses it
Plugins can't ship path-scoped rules or permissions, so init **copies once** and the project owns the result:
`rules/` → `.claude/rules/`, `harness.md` merged into `.claude/harness.md`, `settings.json` merged into `.claude/settings.json`,
`githooks/` → `.githooks/` (+ `scripts/setup-hooks.sh`). `api-standards.md` is copied only if the project has API routes.
`/harness:doctor` diffs the project's copies against this pack so upstream improvements can be pulled in deliberately.

## Judgment calls
- **Migrations `down()`**: starter-kit says fix-forward, path-to-war/eqdata require `down()`. The pack ships fix-forward (newest) and says "check siblings".
- **Factories**: pack allows `HasFactory`; projects that forbid it enforce that with an arch test.
- **CLAUDE.md is not part of the pack.** Laravel Boost generates it (`boost:update`); project-specific guidance goes in `.ai/guidelines/`.
- Boost-covered topics (search-docs, tinker, artisan basics, Pest syntax) are deliberately not repeated.

## Left out (eqdata-specific, stay in that project)
`modules.md`, `provider-modules.md` (modular monolith), `mappers.md`, `nova-components.md` (Laravel Nova), plus eqdata's API v3+ details
(`EQD-` error codes, Cockpit/Embed examples) — only the generic parts survive in `api-standards.md`. life-os's `services-dtos.md` is a
project-specific merge of services + data-objects and was not used.
