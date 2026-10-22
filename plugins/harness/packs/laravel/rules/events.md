---
paths:
  - "app/Events/**"
  - "app/Listeners/**"
---

# Events & Listeners

## Naming — behavior, not data
- Name events after a domain behavior that happened, past tense: `PaymentFailed`, `OrderShipped`.
- No generic record-mutation events (`UserUpdated`, `OrderSaved`): they carry no meaning and force every listener to
  re-inspect the model. One event = one thing that happened; if a listener asks "what changed?", it is too generic.

## Dispatch
- Dispatch from the Action that performed the change, as one atomic unit: persist (inside the DB transaction) **then**
  dispatch. If the mutation fails, the event must not fire.
- Never dispatch an event to *cause* the state change. State is already persisted when listeners run.

## Jobs vs listeners
- **Job** = work the caller asked for; an async boundary, not a step. Dispatched by a Workflow, never by an Action.
- **Listener** = work the mutation *caused* that the writer shouldn't know about (cache warm-up, search index, notification).
  A queued listener covers every write path (web, API, import); a `dispatch()` inside one Action covers only the path
  someone remembered.
- About to add a dispatch to an Action? Caller-requested → move the flow to a Workflow; consequence → queued listener.

## Listeners
- Domain listeners are **queued** (`ShouldQueue`). Synchronous listeners only for framework/package events.
- Each listener owns its failure and must not break the dispatcher or other listeners. Set `$tries`/`backoff` for volatile
  dependencies; use a job chain when order matters.
- Never depend on listener execution order.

## Observers vs events
- Framework-level every-instance concerns → observer (`database-eloquent.md`). Business behavior → domain event + queued listener.
