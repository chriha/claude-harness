---
paths:
  - "tests/**"
---

# Test-Driven Development

Any behavior change is driven test-first (red → green). Pest mechanics (syntax, datasets, factories,
`RefreshDatabase`) live in the `pest-testing` skill; this rule owns the loop.

## The loop
- **Red before green.** Write the failing test, run it, see it fail *for the right reason* (an assertion, not a typo or
  missing class). `php artisan test --compact --filter=<name>`.
- **One cycle at a time.** One seam, one test, minimal code to pass, repeat. No speculative tables/DTOs/config.
- **Red means fix the code, not the test.** Loosening an assertion to match output is green theater. If the test is
  genuinely wrong, get confirmation before editing it.
- **Refactor after green**, not inside the loop. Never batch all tests up front — grow one behavior at a time.

## Seams — where tests go
A **seam** is a public boundary where behavior is observable without reaching inside. Test at seams, never internals.
Good: an Action's `handle()`, a Query result, a Service method, an HTTP endpoint (assert the JSON, not the rows).
Not: Eloquent internals, observers, private helpers.

## A good test
Verifies behavior through a public interface, reads like a spec (WHAT not HOW), one logical assertion, survives refactors.

```php
// GOOD: Action seam in, Query seam out — not assertDatabaseHas
it('makes an assigned role retrievable via the user', function () {
    $user = User::factory()->create();
    $role = Role::factory()->create();

    app(AssignRole::class)->handle($user, $role);

    expect(app(GetUserRoles::class)->handle($user)->pluck('id'))->toContain($role->id);
});
```

## Anti-patterns
- **Implementation-coupled** — mocking internal collaborators, testing private methods, asserting call counts/order
  (`shouldReceive()->once()`). Tell: breaks on refactor with no behavior change. Read back through the same
  Action/Query/endpoint; `assertDatabaseHas` only when the row *is* the contract (e.g. an import).
- **Tautological** — expected value recomputed the way the code computes it (`toBe(array_sum($prices))`). Expected values
  come from an independent source: a literal, a worked example, the spec.
- **Named global functions in test files** — a top-level `function name()` is global to the suite and breaks with
  "Cannot redeclare". Use a closure or a helper in `tests/Pest.php`.

## Mocking — boundaries only
Mock only system boundaries: external APIs/HTTP, time/randomness (`Carbon::setTestNow()`), filesystem (`Storage::fake()`),
queue/mail/event dispatch (`Queue::fake()`). Prefer the real test DB (`RefreshDatabase` + factories). Never mock your own
Actions/Services/Queries. Design boundaries to substitute: inject deps, prefer specific methods over a generic `get($endpoint, $params)`.

## Planning is cycles, not layers
Plan per-behavior cycles (failing test → minimal code), not "build every layer, then test". Enumerate *every* behavior
before sequencing: happy path; every failure path (timeout, empty/null, downstream down); boundaries (empty/zero/one/max,
`>=` vs `>`, first/last); every acceptance criterion; non-obvious seams (config defaults, migrations/constraints, scheduler,
outbound events). Close with a check mapping each source item to its cycle.
