---
paths:
  - "app/Services/**"
---

# Services

A Service answers **"answer a question / compute this / talk to a 3rd party."** It is the collaborator kind:
Actions and Workflows inject Services, never the other way round.

- Encapsulate complex retrieval, 3rd-party integrations and reusable utilities.
- Stateless, focused on one domain/integration, dependency-injected. Use interfaces for 3rd-party integrations.
- **Read-only**: a Service never persists state. If it needs a write, it returns the data and the caller's Action writes it.
- A Service never uses `App\Actions\*`, `App\Workflows\*` or `App\Jobs\*`, and never dispatches a job or domain event
  (keeps the dependency direction total — no cycles).
- Noun naming: suffix the namespace's entry point (`PaymentService`); collaborators inside need no suffix.
- A Strategy or Registry that *answers a question* — including the class that *picks* a strategy — is a Service.
  A strategy that *runs a flow* is a Workflow behind the same interface.

```php
final readonly class GoogleMaps implements GeocodesAddress
{
    public function __construct(
        private HttpClient $http,
        private string $apiKey,
    ) {}

    public function geocode(string $address): ?Result
    {
        // ...
    }
}
```
