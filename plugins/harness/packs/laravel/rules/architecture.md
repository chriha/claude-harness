---
paths:
  - "app/**/*.php"
---

# Project Architecture

Input and delegation layers stay thin: validate, authorize, delegate.

## Four kinds, one direction

Dependencies point one way only — an entry point may call a Workflow or an Action, a Workflow may call an
Action, either may call a Service, and a Service calls only Services. Never the reverse.

| Kind | Directory | Answers | May call | Writes? | Naming |
|------|-----------|---------|----------|---------|--------|
| Entry point | `Http/Controllers`, `Console/Commands`, `Jobs`, `Listeners` | "this was requested / this happened" | Workflow, Action, Query | no | framework convention |
| Workflow | `app/Workflows/` | "run this multi-step flow" | Action, Service, dispatch Job/event | never directly | verb phrase, `handle()` |
| Action | `app/Actions/` | "make this one write" | sub-Action (same write), Service | **yes** | verb phrase, `handle()` |
| Service | `app/Services/` | "answer a question / compute / talk to a 3rd party" | Service | no | noun |

Detail per kind: `workflows.md`, `actions.md`, `services.md`. Jobs vs listeners: `events.md`.
Pure reads: `query-classes.md`.

## File structure

```
app/
├── Actions/          # State mutation (create/update/delete)
├── Console/Commands/ # Thin artisan commands
├── Contracts/        # Interfaces
├── DataObjects/      # Immutable data containers
├── Enums/            # Type-safe enumerations
├── Events/           # Domain events
├── Exceptions/       # Custom exceptions
├── Http/Controllers/ # Thin controllers
├── Http/Requests/    # Form requests
├── Http/Resources/   # API resources (versioned V1/, V2/)
├── Jobs/             # Queued jobs (thin, delegate to Workflows/Actions)
├── Listeners/        # Event listeners
├── Models/           # Eloquent models
├── Observers/        # Model observers
├── Pipes/            # Steps a pipeline/Workflow runs
├── Policies/         # Authorization policies
├── Queries/          # Complex read queries
├── Rules/            # Custom validation rules
├── Services/         # Questions, computation, 3rd-party integration (no state mutation)
├── Support/          # Utilities and helpers
├── Validation/       # Reusable validation rule providers
└── Workflows/        # Multi-step flows (call Actions, dispatch jobs, never write)
```

Organize by domain within each directory: `Actions/Users/`, `Actions/Billing/`. Don't add base folders without approval.

## Naming

| Element | Convention | Example |
|---------|-----------|---------|
| PHP classes | PascalCase | `UserController`, `CreateUser` |
| Methods / variables | camelCase | `getUserName()`, `$orderTotal` |
| Route URLs | kebab-case | `/user-profiles`, `/api/v1/users` |
| Route names | snake_case with dots | `user_profiles.show` |
| Tables / columns | snake_case (tables plural) | `order_items`, `first_name` |
| Config files / keys | kebab-case / snake_case | `pdf-generator.php`, `max_upload_size` |
| Artisan commands | kebab-case | `delete-old-records` |
| Enum cases | TitleCase | `OrderStatus::Pending` |

**Suffix** the class when the suffix disambiguates it (the kinds Laravel's `make:` generators emit):
`Controller`, `Command`, `Job`, `Request`, `Resource`, `Query`, `Policy`, `Observer`, `Exception`, `Factory`,
`Seeder`, `Provider`, `Notification`, `Contract` (interfaces in `App\Contracts`).

**Don't suffix** — the namespace already carries the kind:

| Kind | Convention | Examples |
|------|-----------|----------|
| Actions, Workflows, Pipes, Listeners | verb phrase | `CreateOrder`, `IngestProviderMessages`, `UpdateSearchIndex` |
| Events | past participle | `OrderShipped` |
| Scopes | query fragment | `WhereAge`, `ExcludeDrafts` |
| Rules / Validation | the constraint | `CountryIso2Code` |
| Casts | the cast target | `ResultArray` |
| Models / Enums | bare entity / what it describes | `Order`, `OrderStatus` |

Services: suffix the namespace's entry point (`PaymentService`); collaborators inside a service namespace need none.
Traits live in `Concerns/` and are named as capabilities (`Taggable`).

Enforce what can be enforced with Pest arch tests (`tests/Architecture/`), not prose.
