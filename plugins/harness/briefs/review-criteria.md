# Review criteria (shared)

Single source for rules-compliance and test-quality review. Used by `review` (agents 1, 2, 4, validation) and
the implementer's Review step. Project specifics: harness.md § Test conventions.

## Rules compliance (CLAUDE.md and `.claude/rules/*`)

Audit the changes for CLAUDE.md and rules compliance (no such files → nothing to audit). For a file, only consider
CLAUDE.md files that share a path with the file or its parents.

## Test quality

Review only test files in the diff (`test_file_glob` of harness.md § Scripts). For each test flag violations of:
- **Goal-first:** specifies desired behavior or intent (requirements, edge cases, error handling), not just exercising code paths.
- **Small & focused:** one behavior per test; flag unrelated asserts or excessive setup.
- **Fast & deterministic:** flag I/O, randomness, sleeps, the real clock, network or other externals without a fake.
- **Readable & maintainable:** unclear names, missing arrange/act/assert, duplicated setup that belongs in helpers/data providers.
- **Independent:** no order dependence or shared mutable state.
- **Right level of abstraction:** unit tests that should be integration tests or vice versa, where the mismatch is obvious.
- **Coverage of cases:** missing error paths, boundaries or invalid input when the diff introduces logic that clearly warrants them.
- **Assert behavior, not implementation:** no asserts on internal calls or private details when the outcome is observable.
- Project conventions from harness.md § Test conventions.

Skip when no test files are in the diff.

## Signal threshold

**Only HIGH and MEDIUM SIGNAL issues.** Flag:
- Code that fails to compile or parse (syntax/type errors, missing imports, unresolved references).
- Code that definitely produces wrong results regardless of inputs (clear logic errors).
- Clear, unambiguous CLAUDE.md / rules violations where you can quote the exact rule.

Do NOT flag: style or quality concerns, input/state-dependent maybes, subjective suggestions. Not certain → don't flag.

## Validation

Each issue is validated by a separate sonnet subagent that gets the author intent and the issue and must confirm with high
confidence it is real. For rules issues, confirm the rule is scoped for this file and actually violated. Drop the rest.

## False positives (do NOT flag)

- Pre-existing issues; things that look like bugs but are correct; pedantic nitpicks a senior engineer would skip.
- Anything a linter/formatter/static analysis in harness.md § Commands will catch (don't run it to verify).
- General quality concerns (coverage, generic security) unless explicitly required in CLAUDE.md/rules.
- Issues explicitly silenced in code (e.g. a suppression comment) where CLAUDE.md allows it.
