# Testing y quality gates

Architecture quality must be executable.
No architecture claim is considered valid without observable verification.

## Test levels by layer

### Repository

- unit tests with real test database
- validate SQL behavior, mapping, and transactions

### UseCase

- isolated unit tests for business rules and orchestration
- use mocks only to isolate collaborators

### API

- integration tests with running server
- verify routes, middleware behavior, and contract shape

### Controller

- isolated unit tests with mocked service boundaries
- validate state and interaction flow

### Service and UI

- validate through controller and end-to-end scenarios
- keep E2E focused on critical user journeys

### Database

- schema validation and engine compatibility checks
- run declarative schema verification before release

## Gate stack

Minimum gates:

- lint and format
- type checks (when applicable)
- unit tests
- contract tests
- integration tests
- end-to-end critical checks
- security checks
- release validation checks

## Testing strategy

- test pyramid: mostly unit, fewer integration, minimal E2E
- Red-Green-Refactor loop for each meaningful change
- tests as documentation of behavior, not implementation details
- prioritize business-critical scenarios over vanity coverage metrics

## Anti-flakiness rules

- isolate test state (db, cache, globals)
- deterministic fixtures and seeds
- independent test execution order
- explicit async timeouts and retries only when justified

## Architectural constraints validated by tests

- clear layer responsibilities (`db`, `api`, `app`, `infra`)
- unidirectional request-response flow
- external integrations centralized in `api`
- declarative database-as-code workflow
