---
paths:
  - "app/Workflows/**"
  - "app/Pipes/**"
---

# Workflows

A Workflow answers **"run this multi-step flow."** It sequences Actions, Services and queued work and performs no write itself.

## Rules
- `final readonly` classes in `app/Workflows/`, organized by domain (`Workflows/Import/`). Never extend a base class.
- One public method: `handle(...)` (may also have `__invoke`). Verb-phrase name, no `Workflow` suffix.
- Constructor property promotion for dependencies.
- **Never writes directly**: no `->save()`, `->create()`, `DB::`. Every write goes through an Action.
- May call Actions and Services, dispatch queued Jobs and domain events.
- Not an entry point: a controller, command, job or listener calls it.
- Depends on `App\Contracts`, never on a concrete Service (DIP).

```php
final readonly class IngestProviderMessages
{
    public function __construct(private ImporterRegistry $importers) {}

    public function handle(ProviderPayload $payload): void
    {
        foreach ($payload->messages() as $message) {
            ImportMessageJob::dispatch($message);
        }
    }
}
```

## Jobs
A Job is an **async boundary, not a step**. Add a Job class only when work must cross into the queue — a Workflow with
three steps is one Workflow, not three jobs. An effect the write *caused* is a queued listener (`events.md`).

## Strategy, Registry, Pipeline
The interface lives in `app/Contracts`, the implementation in the tier its behavior puts it in.
- Strategy that runs a flow → Workflow. Strategy that answers a question, or the class that picks one → Service.
- Pipeline → Workflow. `app/Pipes/` holds its steps; a pipe is never an entry point and follows its tier's rules.

| Use a Workflow for | Not for |
|--------------------|---------|
| Fan-out: split a payload, one job per item | A single write (Action) |
| A flow spanning several Actions across writes | Two sub-Actions completing one write (Action composition) |
| Sequencing Actions, Services and queued steps | Answering a question (Service) |
