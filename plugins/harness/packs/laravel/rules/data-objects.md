---
paths:
  - "app/DataObjects/**"
---

# DataObjects (DTOs)

- Use `final readonly class` with constructor property promotion.
- DTOs are pure data containers — their only responsibility is data transfer.
- May include: `toArray()`, `fromArray()`, simple `isEmpty()`.

```php
final readonly class UserContext implements Arrayable
{
    public function __construct(
        public string $userId,
        public string $name
    ) {}

    public static function fromArray(array $data): static
    {
        return new self(
            userId: $data['user_id'],
            name: $data['user_name'],
        );
    }
}
```

## Never in DTOs
- Query database, call external APIs, perform complex calculations, mutate state, implement business logic.
