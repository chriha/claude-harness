---
paths:
  - "app/Http/Controllers/**"
  - "routes/**/*.php"
---

# Controllers & Routing

## Controllers
- Prefer single action controllers with `__invoke()`.
- Controllers are `final readonly`. Never extend a base class — use composition (DI) and middleware.
- Use singular resource names: `CourseController`, not `CoursesController`.
- Stick to default CRUD action names: `index`, `create`, `store`, `show`, `edit`, `update`, `destroy`.
- Controllers should be thin: validate, authorize, delegate to Actions.

## Pattern

```php
final readonly class RecommendationController
{
    public function __construct(private RecommendationService $recommendations) {}

    public function __invoke(ShowRequest $request): ResourceCollection
    {
        $validated = $request->validated();

        // Delegate to service/action, return response
        $result = $this->recommendations->forUser($validated);

        return ProductResource::collection($result);
    }
}
```

## Validation
- Always use Form Request classes — never inline validation in controllers.
- Check sibling Form Requests for whether the app uses array or string based rules.
