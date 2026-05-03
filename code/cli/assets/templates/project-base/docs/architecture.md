# Architecture

## Modules

> List the top-level modules and their responsibilities.

| Module | Responsibility |
|--------|---------------|
| `db`   | Data layer — models, repositories, migrations |
| `api`  | Application layer — use cases, services |
| `ui`   | Presentation layer — views, controllers |

## Layers

```
ui  →  api  →  db
```

- Each layer depends only on the layer below it.
- `db` has no dependency on `api` or `ui`.
- `api` has no dependency on `ui`.

## Cross-cutting Concerns

- **Logging**: centralized logger injected via dependency injection.
- **Configuration**: environment-specific config loaded at startup.
- **Error handling**: typed error hierarchy defined in `api`; propagated to `ui`.
