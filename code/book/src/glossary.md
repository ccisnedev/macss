# Glosario MACSS

Precise definitions of terms used across the MACSS architecture.
Each entry states the layer where the element operates and its responsibility.

For the naming rules and intentional divergences from common usage, see the
Naming Conventions chapter.

---

## Interface (UI / CLI)

**Layer**: Client — presentation.

The visual or textual component that displays information to the user and
captures interactions. Contains no business logic and manages no state — both
are delegated to the Controller.

Origin: MVC (Smalltalk-80, Trygve Reenskaug, 1979). The View renders what the
Controller signals. MACSS uses `Interface` instead of `View` to avoid the
ambiguity that word carries across frameworks.

---

## Controller

**Layer**: Client — presentation.

Manages state for a view and orchestrates calls between the Interface and the
Services. Each view has its own Controller.

Responsibilities:
- receive events from the Interface (tap, submit, input),
- invoke the corresponding Service,
- maintain and expose view state (loading, data, error),
- transform data for presentation when needed.

Origin: Smalltalk-80. The Controller handled user input and coordinated Model
and View. Server-side frameworks (Rails, Spring MVC) reused the name for HTTP
routing because the server was generating the UI. In MACSS, API and UI are
separated, so the Controller returns to its original position: the client.

There is no Controller on the server. HTTP routing plus the UseCase cover that
responsibility without a pass-through layer.

---

## Service (Client)

**Layer**: Client — communication with the server.

Class that encapsulates HTTP calls to the server. One per module
(e.g., `CustomerService`, `SalesService`). Uses `ServiceClient` as the
transport abstraction — currently `HttpServiceClient` for commands (REST),
future `GraphQLClient` for queries.

Rules:
- no direct calls to external APIs from the client — everything goes through
  `api/`,
- the only exception is `/auth/` for authentication.

The domain qualifier is mandatory: `CustomerService`, not `Service`.

---

## Service (Server)

**Layer**: Server — communication with external services.

Class that encapsulates HTTP calls to third-party APIs from the server
(e.g., `PaymentGatewayService`, `EmailDeliveryService`).
Uses `httpClient()` as the transport abstraction.

Difference from Service (Client): the client Service calls the internal API.
The server Service calls external third-party services. Same pattern, different
side of the HTTP boundary.

---

## API

**Layer**: Server — transport.

Backend server that exposes HTTP endpoints. Its responsibility is exclusively
transport: receive an HTTP request, map it to the corresponding UseCase, return
the response as a DTO.

Contains no business logic. Responsibilities: routing, middlewares,
serialization.

Equivalent to what some frameworks call HTTP Handler or Route Handler. MACSS
uses `API` because it names what the layer exposes — a programmatic interface —
not how it is implemented.

---

## UseCase

**Layer**: Server — business logic.

Encapsulates one complete business operation. Exposes an `execute()` function
that receives an Input DTO and returns an Output DTO.

Responsibilities:
- apply business rules,
- orchestrate calls to Repositories (data) and Services (external APIs),
- coordinate transactions when necessary.

Does not parse HTTP, serialize JSON, or manage sessions. Those are API layer
responsibilities.

Origin: Ivar Jacobson, OOSE (1992). In Clean Architecture (Robert C. Martin),
Use Cases are interactors containing application rules. MACSS adopts this
definition: a UseCase is an atomic unit of business logic, executable and
testable in isolation.

---

## DTO (Data Transfer Object)

**Layer**: Cross-cutting — contract between layers.

Object that defines the input and output data shape of a UseCase. It is an
explicit contract, not an implementation detail.

The `validate()` function on an Input DTO applies business rules before the
UseCase processes the data.

Origin: Martin Fowler / J2EE Core Patterns. An object whose only purpose is to
transport data between layers or processes, with no behavior other than
validating its own integrity.

---

## Repository

**Layer**: Server — data access.

Class that executes SQL queries against the database and maps results to domain
entities. It is the boundary between business logic and persistence.

Rules:
- writes SQL directly, no ORM — consistent with Database as Code,
- encapsulates operations for one entity or aggregate,
- the UseCase consumes Repositories; it never accesses the DB directly.

Origin: Eric Evans, Domain-Driven Design (2003). A Repository provides the
illusion of an in-memory collection of domain objects, hiding data access logic.

---

## Module

**Layer**: Internal to each layer — domain organization.

Grouping of related use cases belonging to the same business domain, within one
specific layer. Each layer (db, api, app, cli) organizes its code in modules.

Examples: `api/modules/customers/`, `db/modules/customers/`.

A module is not cross-layer. It is the organizational unit inside one layer,
with explicit boundaries and declared dependencies on other modules in the same
layer.

---

## Slice

**Layer**: Cross-cutting — logical concept, not a physical artifact.

The logical union of same-name modules across all layers for one business
domain.

```
slice "payments" = db/modules/payments
                 + api/modules/payments
                 + app/modules/payments
```

Not a folder. A coherence constraint: if `api/modules/X` exists,
`db/modules/X` must exist. The naming convention materializes the slice.

A slice can be extracted as a microservice without restructuring, because the
boundary was already drawn by the module boundaries.

---

## Middleware

**Layer**: Server — transport, cross-cutting.

Function that executes before or after an HTTP Handler. Implements
cross-cutting concerns: auth, CORS, logging, rate limiting, header validation.

Contains no business logic. Operates at the HTTP transport level.

---

## Database as Code

**Layer**: Persistence.

Declarative approach to managing database schemas through versioned DDL scripts,
instead of incremental migrations or ORMs.

Tools:
- SQL Server: `sqlpackage` — compares the desired state (scripts) with the
  current state and generates a change plan.
- PostgreSQL: `pgschema` — declarative schema management.

The database schema is source code. It is versioned, reviewed in PRs, and
applied reproducibly.

---

## `httpClient()`

**Layer**: Cross-cutting — syntactic sugar.

Convenience function for one-shot HTTP calls. Internally creates a temporary
`ServiceClient`, sends the request, and closes the connection.

When documentation says "use `httpClient()`", it means "use the service client
to make the HTTP call". The implementation lives in the `service_client` package
(Dart, TypeScript, Python).

---

## `usecaseTestHandler()`

**Layer**: Testing.

Tool for testing UseCases in isolation. Provides a controlled environment where
Repositories and Services can be mocked to validate UseCase business logic
exclusively.

---

## OpenAPI

**Layer**: Contract between client and server.

Specification that defines the HTTP API contract: endpoints, methods, request
and response DTOs, error codes. It is the source of truth for client-server
communication.

In MACSS, OpenAPI replaces the need for a shared domain package. Client and
server can be in different languages — OpenAPI is the language-agnostic contract
that synchronizes them.

---

## CQRS

**Layer**: Cross-cutting — architectural principle.

Structural separation between write operations (Commands) and read operations
(Queries). In MACSS, this separation operates at the protocol level:

- Commands → REST/HTTP (POST, PUT, PATCH, DELETE). Each endpoint is a UseCase
  that mutates state.
- Queries → GraphQL. The client requests exactly the fields it needs. Resolvers
  are GET UseCases.

Origin: Greg Young formalized CQRS as a pattern in 2010. MACSS applies it at
the transport level: commands and queries flow through distinct protocols with
distinct validation and distinct contracts (OpenAPI vs GraphQL Schema).

---

## Command

**Layer**: Server — write operation.

A UseCase that mutates state. Exposed as a REST endpoint
(POST, PUT, PATCH, DELETE). Has strict validation via `validate()` and Input
DTO. Returns an Output DTO with the result of the operation.

---

## Query

**Layer**: Server — read operation.

A GET UseCase that reads data without mutating state. Exposed as both a REST
endpoint and a GraphQL resolver (via plugin). The GraphQL plugin only mounts GET
UseCases — never commands.

---

## GraphQL (in MACSS)

**Layer**: Server — read transport.

Read layer auto-generated by the `modular_api_graphql` plugin. Not written
manually — the plugin detects registered GET UseCases, generates a GraphQL type
per Output, and exposes them as queries.

Rules:
- GraphQL serves queries only. Mutations do not exist in MACSS — commands use
  REST.
- Resolvers call the UseCase internally, respecting `validate()`, logging, and
  metrics.
- The schema is generated automatically from DTOs, same as OpenAPI.

---

## Gate

**Layer**: Process — verification checkpoint.

An automated verification point that must pass before a change is considered
complete. Includes: tests (unit, contract, integration, e2e), lint, format,
typecheck, security, performance.

In MACSS, gates are the sensors of the closed-loop development model. The AI
agent iterates until all gates pass.

---

## Event Bus / Queue

**Layer**: Server — asynchronous communication.

Communication channel between UseCases that operates asynchronously. A producer
UseCase publishes an event; one or more consumer UseCases react.

Can be in-process (same server) or distributed (RabbitMQ, Kafka, etc.).
