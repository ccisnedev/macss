## Estructura de carpetas

La aplicación se organiza en cuatro directorios principales que separan claramente las responsabilidades:

```
/docs/
/code
├── infra/
├── db/
├── api/
└── ui/
README.md
```

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

### `ui/` (/cli también entra en esta categoría)

Aplicación cliente que consume el API:

- **Patrón**: MVC/MVVM
- **Service (por módulo)**: Clases que encapsulan las llamadas HTTP al API
    - **No hay llamadas directas a APIs externas**: todo se canaliza a través de `api/v<>/`
    - La única otra api es /auth/ para autenticación, que puede tener una url diferente pero sigue el mismo patrón de Service
- **Controller**: Orquesta las llamadas entre la UI y las clases Service
    - Cada widget/vista tiene su propio Controller
- **UI**: Componentes visuales que reaccionan a los cambios de estado del Controller

---