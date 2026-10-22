# <project>

<one or two lines: what this is, where the docs are>

## Commands
<!-- test / lint / build — keep in sync with .claude/harness.md § Commands -->

## Layout
<!-- where code lives, by concern -->

## Conventions
<!-- 5–10 lines max; stack rules live in .claude/rules/ -->

## Git
- Branches: `<type>/<id>-<slug>`; Conventional Commits; PRs closed via the tracker's closing keyword. Agents open drafts and never merge or mark ready.

## Agent workflow
Ticket pipeline via the `harness` plugin: `/harness:ticket`, `/harness:work-tickets`, `/harness:local-code-review`, `/harness:work-on-comments`.
Project config: `.claude/harness.md`; overrides: `.claude/harness/`.
