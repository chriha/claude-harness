---
paths:
  - "app/**/*.php"
  - "tests/**/*.php"
---

# PHP Standards

## Types
- Explicit return types on every method/function (`void` when nothing is returned), nullable `?Type` when it can be null.
- Constructor property promotion when all properties qualify.

## Docblocks
- Only where they add value beyond type hints; one-line when possible: `/** @var string */`.
- Specify key and value types (`array<string, int>`), array shapes for fixed keys, `Collection<int, User>` for collections.
- Import class names; never use fully qualified names in docblocks.

## Control flow
- Early returns: error conditions first, happy path last. Avoid `else`.
- Short ternaries on one line; multi-line ternaries put each part on its own line.
- Extract complex conditions into expressive boolean methods (`isEligibleForDiscount()`).
- Keep cognitive complexity low.

## Strings
- Interpolation over concatenation: `"Welcome, {$user->name}!"`.
