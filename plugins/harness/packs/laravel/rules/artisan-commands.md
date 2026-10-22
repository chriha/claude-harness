---
paths:
  - "app/Console/Commands/**"
---

# Artisan Commands

## Rules
- Use kebab-case for command names: `delete-old-records`, not `deleteOldRecords`.
- Inject dependencies in `handle()`, NOT in the constructor. Laravel instantiates ALL commands on every `artisan` call.
- Return proper exit codes: `self::SUCCESS` (0) or `self::FAILURE` (1).
- Keep commands thin: delegate business logic to Actions or Services.

## Pattern

```php
final class ProcessImportCommand extends Command
{
    protected $signature = 'import:process';

    public function handle(ImportService $service): int
    {
        $service->processImport();

        return self::SUCCESS;
    }
}
```

## Best Practices
- Validate input using command arguments and options.
- Provide feedback with `$this->info()`, `$this->warn()`, `$this->error()`.
- Catch and handle exceptions gracefully.
