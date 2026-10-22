---
paths:
  - "app/Models/**"
  - "database/migrations/**"
  - "database/factories/**"
  - "app/Observers/**"
---

# Database & Eloquent

## Models
- Use a custom `EloquentBuilder` class for models with 5+ query scopes:

```php
class Transfer extends Model
{
    #[\Override]
    public function newEloquentBuilder($query): TransferEloquentBuilder
    {
        return new TransferEloquentBuilder($query);
    }
}
```

- Use invokable scope classes for reusable scopes: `Transfer::query()->tap(new AgeBetween(7, 10))->get()`.
- Set casts via the `casts()` method, not the `$casts` property. Follow existing model conventions.

## Factories
- Factories are for tests only. Models with a factory use `HasFactory`; call `Transfer::factory()->create([...])`.
  (If the project forbids `HasFactory`, its arch test says so — follow that.)
- `definition()` sets a valid default state; use separate state methods for other states.

## Migrations
- Don't write `down()` by default; fix forward with a new migration. Exception: when `up()` moves or destroys
  data, write a `down()` that restores it and cover it with a test. (Project may require `down()` — check siblings.)
- Never edit a merged migration's `up()` — add a new one. Leave existing `down()` methods alone.
- Use `shouldRun()` to conditionally control execution.
- When modifying a column, include ALL previously defined attributes — otherwise they are dropped.
- Deploys stay backward compatible: expand → migrate → contract; old and new code must run against the same schema.

## Query optimization
- Eager load relationships (N+1), select only needed columns, index frequently queried columns, chunk large sets.
- Prefer `Model::query()` over the `DB::` facade.

## Observers
- Only for framework-level concerns that apply to ALL instances (UUIDs, audit logs, cascade deletes).
- Business behavior is an Action + domain event, never an observer.
