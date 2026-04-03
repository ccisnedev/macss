## Pruebas por nivel

Esta sección complementa el flujo de desarrollo vertical, proporcionando una referencia rápida del tipo de pruebas aplicables en cada capa de la arquitectura.

### Repository

- **Tipo**: Unit tests con conexión real a base de datos de pruebas
- **Alcance**: Validar queries SQL, mapeo de entidades, manejo de transacciones
- **Estrategia**: Tests contra instancia dedicada de DB (Docker/CI) con datos controlados

### UseCase

- **Tipo**: Unit tests aislados con `usecaseTestHandler()`
- **Alcance**: Lógica de negocio, reglas de validación, orquestación de repositorios y servicios externos
- **Estrategia**: Usar mocks de Repository y Service cuando sea necesario para aislar la lógica

### API

- **Tipo**: Integration tests con servidor en ejecución
- **Alcance**: Flujos completos HTTP, rutas, middlewares, contratos de API
- **Estrategia**: Levantar servidor de pruebas y validar con `httpClient()`

### Service (App)

- **Tipo**: Tests a través de los Controllers (no se prueban de forma aislada)
- **Alcance**: Construcción de requests HTTP, manejo de responses, transformación de DTOs
- **Estrategia**: Los Services se validan implícitamente al probar los Controllers

### Controller (App)

- **Tipo**: Unit tests con Service mockeado
- **Alcance**: Lógica de presentación, gestión de estado, orquestación de llamadas
- **Estrategia**: Mockear Service para validar la lógica del Controller de forma aislada

### UI (App)

- **Tipo**: Integration tests End-to-End
- **Alcance**: Flujos completos de usuario desde UI hasta DB
- **Estrategia**: Usar entorno de staging con DB de pruebas; mantener tests E2E concisos y enfocados en casos críticos

### DB

- **Tipo**: Validación de esquemas y compatibilidad
- **Alcance**: Scripts DDL, integridad referencial, compatibilidad entre motores (SQL Server, Oracle, PostgreSQL)
- **Estrategia**: Validar en entorno aislado antes de aplicar en producción usando `sqlpackage` o `pgschema`

---

## Recomendaciones generales

### Clasificación de pruebas

- **Unit tests**: Rápidos, aislados, sin dependencias externas (o con mocks)
- **Integration tests**: Combinan múltiples componentes, pueden usar DB/API de pruebas
- **E2E tests**: Flujos completos desde UI hasta DB, más lentos pero de mayor cobertura

### Estrategia de testing

1. **Pirámide de pruebas**: Mayoría de unit tests, menos integration tests, mínimo de E2E
2. **TDD en todas las etapas**: Red → Green → Refactor
3. **Tests como documentación**: Cada test debe ser legible y expresar claramente el caso de uso
4. **Cobertura significativa**: Priorizar casos críticos de negocio sobre porcentaje de cobertura

### Mecanismos útiles

- **`usecaseTestHandler()`**: Herramienta para probar UseCases de forma aislada
- **`httpClient()`**: Abstracción para comunicación HTTP (Service ↔ API, UseCase ↔ servicios externos)
- **Factories/Fixtures**: Patrones para generación de datos de prueba consistentes y reproducibles
- **Test databases**: Instancias dedicadas que se limpian entre tests para garantizar aislamiento

### Prevención de falsos positivos

- Limpiar estado entre tests (DB, cache, estado global)
- Seeds reproducibles y determinísticos
- Timeouts apropiados para operaciones asíncronas
- Independencia entre tests (cada test debe poder ejecutarse de forma aislada)

---

## Principios arquitectónicos

### Separación de responsabilidades

Cada capa tiene una responsabilidad única y bien definida:

- **`db/`**: Persistencia como código (scripts DDL, Database as Code)
- **`api/`**: Lógica de negocio y exposición HTTP (UseCases, Repository, endpoints)
- **`ui/`**: Presentación y experiencia de usuario (UI, Controllers, Services)

### Flujo unidireccional de datos

Usuario → UI → Controller → Service → [HTTP] → API → UseCase → Repository → DB
↓
Usuario ← UI ← Controller ← Service ← [HTTP] ← API ← UseCase ← Repository ← DB

```

El flujo es **unidireccional** en cada capa:
- Facilita el razonamiento sobre el código
- Simplifica la depuración y el tracing
- Reduce acoplamiento entre capas

### Database as Code (sin migraciones)

En lugar de migraciones incrementales, se usa un enfoque declarativo:

- **SQL Server**: `sqlpackage` compara el estado deseado (scripts) con el estado actual y genera el plan de cambios
- **PostgreSQL**: `pgschema` gestiona esquemas de forma declarativa
- **Ventajas**:
  - ✅ Reproducibilidad total del esquema
  - ✅ Sincronización entre entornos más confiable
  - ✅ Rollback más predecible
  - ✅ Auditoría clara del estado deseado

### Principio Insert-Only

Las operaciones de modificación se implementan mediante inserciones:

- **No hay UPDATE ni DELETE** en tablas de datos de negocio
- Cada cambio genera un nuevo registro
- **Beneficios**:
  - ✅ Auditoría completa (quién, qué, cuándo)
  - ✅ Trazabilidad histórica total
  - ✅ Simplificación de concurrencia
  - ✅ Facilita análisis temporal y rollback

### Contratos compartidos (`domain/`)

El package `domain/` actúa como fuente única de verdad:

- Usado tanto por `api/` como por `app/`
- Garantiza consistencia en los contratos
- Facilita versionado de API (agregar campos vs. breaking changes)
- Reduce duplicación y riesgo de desincronización

### Comunicación externa centralizada

- **Todas las llamadas a APIs externas** se hacen desde `api/`, nunca desde `app/`
- `app/` solo conoce el API interno
- **Beneficios**:
  - ✅ Centralización de lógica de integración
  - ✅ Facilita caching, rate limiting, circuit breakers
  - ✅ Aislamiento de cambios en APIs de terceros

---

## Estrategia de testing

### Pirámide de pruebas
```

```
      / \
     /e2e\         ← Pocos, lentos, alto valor (flujos críticos)
    /-----\
   /-Integ-\       ← Moderados, validar contratos entre capas
  /---------\
 /-Unit Test-\     ← Muchos, rápidos, lógica aislada
/-------------\

```

- **Base (Unit)**: Mayoría de tests, rápidos, lógica aislada (Repository, UseCase, Controller)
- **Medio (Integration)**: Validar interacción entre componentes (API completa)
- **Cima (E2E)**: Flujos críticos de usuario completos (UI → DB)

### Test-Driven Development (TDD)

**Ciclo Red-Green-Refactor** en todas las etapas:

1. **Red**: Escribir test que falle (define el comportamiento esperado)
2. **Green**: Implementar el mínimo código para que el test pase
3. **Refactor**: Mejorar el código manteniendo los tests en verde

**Beneficios del TDD**:
- ✅ Diseño emergente (la API se diseña desde el consumidor)
- ✅ Cobertura automática (los tests nacen con el código)
- ✅ Confianza en refactorizaciones
- ✅ Documentación viva (los tests expresan el comportamiento esperado)

### Tests como documentación

Cada test debe:
- Tener un nombre descriptivo que exprese el caso de uso
- Ser legible sin necesidad de leer la implementación
- Seguir el patrón AAA (Arrange, Act, Assert)
- Expresar claramente la entrada, acción y resultado esperado
```