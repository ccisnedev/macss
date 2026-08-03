# CQRS y GraphQL

MACSS aplica separacion comando-consulta a nivel de protocolo.
No es una convencion de nombres: es una restriccion estructural.

## The split

| Type | Transport | Description |
|------|-----------|-------------|
| **Command** (write) | REST / HTTP | POST, PUT, PATCH, DELETE. Each endpoint maps to a UseCase that mutates state. Strict validation via `validate()` + Input DTO. |
| **Query** (read) | GraphQL | The client requests exactly the fields it needs. No over-fetching. GraphQL is auto-generated from GET UseCases. |

## Rules

- GET UseCases are pure queries — they do not mutate state.
- POST / PUT / PATCH / DELETE UseCases are commands.
- The GraphQL plugin only mounts GET UseCases as resolvers — never commands.
- All logic passes through a UseCase, whether REST or GraphQL — one audit point.
- The contract between server and client is: OpenAPI for commands, GraphQL Schema for queries.

## CQRS flow diagram

The following diagram shows both paths — a write action through REST and a read
action through GraphQL — from the same client.

→ [diagrams/cqrs-flow.md](../../diagrams/cqrs-flow.md)

GraphQL is integrated as a subsystem capability in `modular_api`.
The schema is generated automatically from Output DTOs.
No manual schema writing is required.
