---
paths:
  - "app/Queries/**"
---

# Query Classes

## Rules
- Query classes are `final readonly`. Never extend a base class.
- One public method only: `handle(...)` (besides `__construct`). Constructor property promotion for dependencies.
- Reads only — never mutate state (that is an Action).
- Use when the query is reused, has complex conditions, involves joins/subqueries, or needs its own test.
- Controllers inject the query and call `handle()`; no `Model::query()` / `findOrFail` in controllers.
- One lookup query per model (`FindUserQuery`), no generic finder.
- Document return types with generics: `@return Collection<int, Item>`.
- Every query class has a feature test.

## Pattern

```php
final readonly class UnresolvedTasksQuery
{
    /** @return Collection<int, Task> */
    public function handle(User $user): Collection
    {
        return Task::query()
            ->where('user_id', $user->id)
            ->whereNull('resolved_at')
            ->get();
    }
}
```

Keep complex conditions in private helper methods.
