## Estructura de carpetas

Un monorepo MACSS organiza una solución integral de software en capas horizontales. Cada capa contiene módulos por dominio de negocio. La unión de módulos homónimos a través de las capas forma un **slice** (rebanada vertical).

```
<monorepo>/
├── code/
│   ├── infra/               ← infraestructura (IaC, Docker, CI/CD)
│   ├── db/                  ← capa de datos
│   │   └── modules/
│   │       ├── customers/   ← schema, seeds del dominio Clientes
│   │       ├── sales/
│   │       └── inventory/
│   ├── api/                 ← capa de lógica de negocio
│   │   └── modules/
│   │       ├── customers/   ← usecases, repositories, endpoints
│   │       ├── sales/
│   │       └── inventory/
│   ├── app/                 ← capa de presentación (UI)
│   │   └── modules/
│   │       ├── customers/   ← services, controllers, vistas
│   │       ├── sales/
│   │       └── inventory/
│   └── cli/                 ← capa de presentación (CLI)
│       └── modules/
│           ├── customers/
│           └── sales/
├── docs/
│   ├── adr/                 ← Architecture Decision Records
│   ├── architecture.md
│   └── roadmap.md
├── .gitignore
└── README.md
```

### Capas (horizontales del pastel)

| Capa | Responsabilidad |
|------|----------------|
| `infra/` | Infraestructura como código: Docker, Terraform, pipelines CI/CD, configuración de ambientes |
| `db/` | Database as Code: scripts DDL declarativos, seeds, sin ORMs ni migraciones incrementales |
| `api/` | Backend: UseCases, Repositories, Services, endpoints HTTP. Framework: `modular_api` |
| `app/` | Cliente UI: Services (HTTP), Controllers (estado), Interfaces (vistas). Patrón MVC |
| `cli/` | Cliente CLI: mismo patrón que app/ pero con interfaz textual |

### Módulos (dentro de cada capa)

Cada capa organiza su código en `modules/`, un directorio por dominio de negocio:

- `modules/customers/` — todo lo relativo a Clientes dentro de esa capa
- `modules/sales/` — todo lo relativo a Ventas dentro de esa capa

### Slices (concepto transversal)

Un slice **no es una carpeta** — es la unión lógica de módulos homónimos:

```
slice "customers" = db/modules/customers
                  + api/modules/customers
                  + app/modules/customers
                  + cli/modules/customers (opcional)
```

**Invariante**: si existe `api/modules/X/`, debe existir `db/modules/X/`.

---

### `infra/`

Infraestructura como código:

- **Docker**: Dockerfiles, docker-compose para desarrollo local
- **IaC**: Terraform, Pulumi o scripts de provisioning
- **CI/CD**: Workflows de GitHub Actions, pipelines
- **Config**: Variables de entorno por ambiente (dev, staging, prod)

### `db/`

Implementa el enfoque **Database as Code** (sin migraciones tradicionales):

- **Scripts de creación**: Base de datos, esquemas y tablas
- **Herramientas por motor**:
    - **SQL Server**: `sqlpackage` para despliegue declarativo
    - **PostgreSQL**: `pgschema` para gestión de esquemas

### `api/`

Backend que expone la lógica de negocio mediante HTTP:

- **Framework**: `modular_api` para organización modular
- **UseCase**: Implementación de la función `execute()` que contiene:
    - Lógica de negocio
    - Validaciones
- **DTOs**: Objetos de transferencia de datos (Input/Output) para cada caso de uso
- **Función `validate()`**: Validaciones de negocio aplicables a los DTOs
- **Repository**: Clases que ejecutan queries SQL contra la base de datos
- **Service**: Clases que encapsulan llamadas a APIs externas (con `httpClient()`)
- **Endpoints**: Exposición HTTP de los casos de uso

### `app/` y `cli/`

Aplicaciones cliente que consumen el API:

- **Service (por módulo)**: Clases que encapsulan las llamadas HTTP al API
    - **No hay llamadas directas a APIs externas**: todo se canaliza a través de `api/`
    - La única otra api es `/auth/` para autenticación
- **Controller**: Orquesta las llamadas entre la interfaz y las clases Service
    - Cada vista tiene su propio Controller
- **Interfaz**: Componentes visuales (app) o textuales (cli) que reaccionan al estado del Controller

---