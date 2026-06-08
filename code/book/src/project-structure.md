# Estructura canonica de proyecto

La estructura de directorios de MACSS no es decorativa. Es arquitectura visible.

Quien entiende esta estructura entiende capas, modulos, contratos y ownership.

## Por que un monorepo con contexto completo

Un enfoque comun separa API, frontend y DB en repos distintos.
MACSS prioriza contexto completo para razonar el sistema extremo a extremo.

Un solo workspace integra infraestructura, datos, backend, interfaces, documentacion y tooling.
Esto reduce friccion y facilita trabajo coordinado de humanos y agentes AI.

## Estructura canonica

```text
<project>/
├── code/
│   ├── infra/               ← infrastructure as code
│   │   ├── docker/
│   │   ├── terraform/
│   │   └── ci/
│   ├── db/                  ← database as code
│   │   └── modules/
│   │       ├── customers/
│   │       ├── sales/
│   │       └── inventory/
│   ├── api/                 ← backend use cases and transport
│   │   └── modules/
│   │       ├── customers/
│   │       ├── sales/
│   │       └── inventory/
│   ├── app/                 ← UI client (Flutter, web, etc.)
│   │   └── modules/
│   │       ├── customers/
│   │       └── sales/
│   └── cli/                 ← CLI client surface (optional)
│       └── modules/
│           └── customers/
├── docs/
│   ├── adr/                 ← Architecture Decision Records
│   │   └── 0001-record-architecture-decisions.md
│   ├── architecture.md      ← architecture overview
│   └── roadmap.md           ← delivery roadmap
├── CHANGELOG.md             ← versioned change history
├── .gitignore
└── README.md
```

## Cada parte tiene una responsabilidad

**`code/`** is the root of all executable and deployable artifacts.
Separating code from documentation is a structural contract, not a style
preference. It makes it unambiguous what belongs to the system and what
describes it.

**`code/infra/`** contains everything the system needs to exist in an
environment: Docker, infrastructure-as-code, and CI/CD configuration.
It is the plate of the layer cake — invisible when the system runs well,
essential when it does not.

**`code/db/`** contains Database as Code: declarative DDL scripts, schema
definitions, and seeds organized by domain module. There are no migration
files, no ORMs, no hidden schema state. The database is auditable and
reproducible from these scripts alone.

**`code/api/`** contains the backend. Use cases, repositories, transport
endpoints, and subsystem integrations like `modular_api` live here,
organized by domain module.

**`code/app/`** and **`code/cli/`** are client surfaces. Each has the same
internal module structure as the backend. The shape is symmetric by design:
`app/modules/customers` mirrors `api/modules/customers`.

**`docs/`** contains only architectural and decision documentation.
It is not a catch-all. Code-level documentation belongs next to the code.
Cross-cutting decisions and rationale belong here.

**`docs/adr/`** is the permanent log of architectural decisions.
Every significant design choice should have an ADR so future contributors
— human or AI — can understand not only what the system does but why.

**`CHANGELOG.md`** records delivery history at the project level.
It is the readable history of the system's evolution.

## Materialized by `macss create`

This structure is not something a team has to define from scratch.
The command `macss create` produces it.

```text
macss create --path=./my-project
```

Running this command gives you a clean project workspace with:

- the standard `code/` layer skeleton,
- the `docs/` hierarchy with the ADR starting point,
- a baseline `README.md`, `CHANGELOG.md`, and `.gitignore`,
- and all the structural conventions required by the architecture.

The structure is not locked. Teams can add layers, rename modules, or extend
the cli and app surfaces. But the skeleton is the minimum expression of a
MACSS project, and `macss create` is its materialization.

## Why structure is architecture

The structure enforces rules that would otherwise live only in documentation:

- If `api/modules/X` exists, `db/modules/X` must also exist.
- Client modules mirror backend modules by name.
- Documentation is never mixed with code.
- Decisions are recorded near the architecture they affect.

These are not style guidelines. They are constraints that make the system
navigable, testable, and extractable — a single module can become a
microservice without reorganization, because the structure already drew the
boundary.
