---
paths:
  - "app/Actions/**"
---

# Action Classes

An Action answers **"make this one write."** It is the only kind that mutates state.
The multi-step flow that leads to a write is a Workflow (`workflows.md`); the
collaborator that answers a question is a Service (`services.md`).

## Rules
- Actions are `final readonly` classes. Never extend a base class.
- One public method only: `handle(...)` (may also have `__invoke`).
- Use constructor property promotion for dependencies.
- Actions perform state mutation: create, update, delete operations.
- An Action **may** dispatch its own domain event — firing "this happened" is part of mutating (`events.md`).
- An Action **never** dispatches a queued job. Work that must cross into the queue belongs to a Workflow
  (work the caller asked for) or a queued listener on the domain event (an effect the write *caused*).
- Actions may contain lightweight assertions/guards for domain invariants, but do not own full validation.
- Actions may call Services and sub-Actions that complete the same write (below). They never call a Workflow.

## Pattern

```php
final readonly class ApplyChangeRequest
{
    public function __construct(
        private SomeDependency $dependency,
    ) {}

    public function handle(ChangeRequest $request): ChangeRequest
    {
        $this->assertPreconditions($request);

        // Business logic here...

        return $request;
    }

    private function assertPreconditions(ChangeRequest $request): void
    {
        if ($request->isBlocked()) {
            throw new ChangeRequestException('Cannot apply blocked request.');
        }
    }
}
```

## Composition — one write only

Inject sub-Actions **only when they complete the same write**: same transaction, same aggregate.
Anything crossing that boundary is a domain event or a Workflow step.

```php
final readonly class ApproveChangeRequest
{
    public function __construct(
        private DatabaseManager $db,
        private ApplyChangeRequest $apply,
        private RecordApproval $recordApproval,
    ) {}

    public function handle(ChangeRequest $request): void
    {
        $this->db->transaction(function () use ($request): void {
            $this->apply->handle($request);
            $this->recordApproval->handle($request);
        });

        ChangeRequestApproved::dispatch($request);
    }
}
```

A class that writes nothing and only calls other Actions or queues work is not an Action — it is a Workflow.

## Action vs Workflow vs Service

| Aspect | Action | Workflow | Service |
|--------|--------|----------|---------|
| Purpose | Make one write | Run a multi-step flow | Answer a question / 3rd party |
| Writes state | yes, that's its job | never directly | never |
| Fires a domain event | yes, for its own change | yes | no |
| Dispatches a job | **no** | yes | no |
| May call | sub-Action (same write), Service | Action, Service, Job, event | Service |
| Naming | verb phrase: `CreateOrder` | verb phrase: `IngestProviderMessages` | noun: `PaymentService` |

Don't use an Action for: pure retrieval (Query class), utilities (Service), multi-step flows / fan-out (Workflow).
