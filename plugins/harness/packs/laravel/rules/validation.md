---
paths:
  - "app/Http/Requests/**"
  - "app/Rules/**"
  - "app/Validation/**"
---

# Validation

- Always use Form Request classes for validation — never inline in controllers.
- Check sibling Form Requests for whether the app uses array or string based rules.
- Use custom Rule classes in `app/Rules/` for complex validation logic.
