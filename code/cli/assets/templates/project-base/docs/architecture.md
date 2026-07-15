# Architecture

## Modules

> List the top-level modules and their responsibilities.

| Module  | Responsibility |
|---------|---------------|
| `db`    | Data layer — models, repositories, migrations |
| `api`   | Application layer — use cases, services |
| `app`   | Presentation layer — views, controllers |
| `infra` | Infrastructure — provisioning and deployment (transversal, optional) |

## Layers

```
app  →  api  →  db
```

- Each layer depends only on the layer below it.
- `db` has no dependency on `api` or `app`.
- `api` has no dependency on `app`.

`infra` is not part of this chain. It is transversal: it provisions and deploys
the layers above, so it knows them, but they never import `infra`. It is also
optional — a project is valid without it.

## Request flow

A single request traverses the layers as follows. The `client` box maps to the
`app` module, `server` to `api`, and `database` to `db`.

```mermaid
sequenceDiagram
    actor U as User
    box client
    participant UI as Interface
    participant C as Controller
    participant S as Service
    end
    box server
    participant API as API
    participant UC as UseCase
    participant REPO as Repository
    end
    box database
    participant DB as DB
    end

    U-->>UI: Interaction
    UI->>C: Event
    C->>S: Service call
    S-->>API: HTTP Request
    API->>UC: Map to UseCase
    UC->>REPO: Query / Command
    REPO-->>DB: SQL
    DB-->>REPO: Results
    REPO->>UC: Entities
    UC->>API: Response DTO
    API-->>S: HTTP Response
    S->>C: Data / Error
    C->>UI: Update state
    UI-->>U: Display result
```

## Cross-cutting Concerns

- **Logging**: centralized logger injected via dependency injection.
- **Configuration**: environment-specific config loaded at startup.
- **Error handling**: typed error hierarchy defined in `api`; propagated to `app`.
