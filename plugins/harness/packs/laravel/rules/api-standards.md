---
paths:
  - "app/Http/Controllers/Api/**"
  - "app/Http/Resources/**"
  - "routes/api*.php"
  - "routes/api/**"
  - "tests/**/Api/**"
---

# API Standards

Opt-in rule for projects that expose an HTTP API. Adjust to the project's existing contract; legacy versions are left alone unless asked.

- **URL:** `/api/v{n}/…`, kebab-case segments, plural collections, verbs only beyond CRUD. Path/query params camelCase.
- **Verbs:** POST create (201), PUT replace, PATCH partial, GET read, DELETE remove (204/202/200).
- **Success:** wrap under top-level `data`, entity in a named container (`data.order`), never an array for a single entity.
- **Fields:** camelCase. Use API Resources — never return raw models, no overfetching.
- **Errors:** RFC 9457 `application/problem+json` (`type`, `title`, `detail`, `status`, unique `code`); validation errors as
  `errors[]` with `detail` + `pointer`. No stack traces, framework names or paths outside dev/test.
- **Pagination:** page-based by default, top-level `pagination` sibling of `data`; cursor only if performance-justified.
- **Misc:** UUIDs for external ids, `Accept-Language` for localization, `Authorization: Bearer`, ETag + 304 on cacheable GETs.
- **Docs & tests:** every endpoint documented in the OpenAPI spec (incl. each error code); ship a feature test (happy +
  failure paths) and, where the project has spec-conformance tooling, a test per documented status.
