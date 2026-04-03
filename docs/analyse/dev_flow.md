## Flujo de desarrollo vertical (TDD)

El desarrollo de funcionalidades sigue un enfoque **bottom-up** con Test-Driven Development (TDD) en cada etapa. Este proceso garantiza la calidad y correctitud desde la base de datos hasta la interfaz de usuario.

### Etapa 0: Diseño y contratos

**Objetivo**: Establecer los fundamentos arquitectónicos antes de la implementación.

**Actividades**:

1. **Esquema de base de datos** (`db/`)
    - Diseñar tablas siguiendo el principio **insert-only**
    cada entidad tiene: hub, satelite (para cambio de estado) y vista (para consulta)
    - Definir scripts DDL de creación (DB, esquemas, tablas)
    - Establecer relaciones, constraints e índices
2. **Contratos DTO**
    - Definir DTOs de Input y Output para cada caso de uso
    - Implementar funciones `validate()` con reglas de validación
3. **Definición de UseCases**
    - Especificar interfaces/clases abstractas de casos de uso
    - Documentar la firma de la función `execute()` y sus responsabilidades

**Entregables**:

- Scripts DDL en `db/`
- Maquinas de estados finitos de los flujos `domain/flows/<flow>`
- Interfaces de UseCases en `domain/flows/<flow>/usecases/`
- Contratos DTO en `domain/flows/<flow>/usecases/<usecase>/dto/`

---

### Etapa 1: Repository y persistencia

**Ubicación**: `db/` y `api/repository/`

**Objetivo**: Implementar y validar las consultas SQL y la interacción con la base de datos.

**Proceso TDD**:

1. Escribir tests unitarios que validen el comportamiento esperado del Repository
2. Implementar las funciones del Repository con queries SQL
3. Ejecutar tests contra instancia de DB de pruebas
4. Refactorizar hasta que todos los tests pasen

**Validación**:

- ✅ Los queries ejecutan correctamente
- ✅ Los resultados se mapean correctamente a entidades
- ✅ Manejo adecuado de errores de conexión y constraints

---

### Etapa 2: UseCase - Lógica de negocio

**Ubicación**: `api/usecases/`

**Objetivo**: Implementar la función `execute()` de cada UseCase definido en `domain/`, aplicando las reglas de negocio.

**Proceso TDD**:

1. Escribir tests unitarios para el UseCase usando `usecaseTestHandler()`
2. Implementar la función `execute()` del UseCase:
    - Llamadas a Repository para acceso a datos
    - Llamadas a servicios externos (mediante clase `Service` con `httpClient()`)
    - Aplicación de reglas de negocio
3. Ejecutar tests y refactorizar hasta que todos pasen

**Validación**:

- ✅ La lógica de negocio se ejecuta correctamente
- ✅ Transacciones y operaciones complejas funcionan como se espera
- ✅ Manejo correcto de casos límite y errores de negocio

---

### Etapa 3: API - Integración de flujos

**Ubicación**: `api/routes/` y `api/middlewares/`

**Objetivo**: Validar los flujos completos del servidor (HTTP request → UseCase → Repository → DB → Response).

**Proceso TDD**:

1. Escribir tests de integración que arranquen el servidor
2. Implementar rutas que mapeen requests HTTP a UseCases
3. Implementar middlewares (auth, CORS, validación)
4. Ejecutar tests con `httpClient()` y refactorizar hasta que todos pasen

**Validación**:

- ✅ Las rutas HTTP responden correctamente (200, 4xx, 5xx)
- ✅ Los DTOs se serializan/deserializan correctamente
- ✅ Middlewares funcionan como se espera
- ✅ Los flujos completos end-to-end en el backend son correctos

---

### Etapa 4: Service y Controller (App)

**Ubicación**: `app/services/` y `app/controllers/`

**Objetivo**: Implementar la capa de comunicación con el API y la lógica de presentación.

**Proceso TDD**:

1. Escribir tests unitarios para el Controller
2. Implementar el Controller con llamadas a la clase `<Modulo>Service`
3. Implementar la clase Service con `httpClient()` para comunicarse con el API
    - **Importante**: No hay llamadas directas a APIs externas desde `app/`
4. Ejecutar tests y refactorizar hasta que todos pasen

**Validación**:

- ✅ El Controller orquesta correctamente las llamadas al Service
- ✅ El Service construye correctamente las requests HTTP
- ✅ Manejo adecuado de errores de red y respuestas inesperadas
- ✅ El estado se actualiza correctamente en base a las respuestas

---

### Etapa 5: UI y tests de integración (App)

**Ubicación**: `app/ui/` o `app/views/`

**Objetivo**: Implementar las vistas y validar los flujos completos desde la UI hasta la DB.

**Proceso TDD**:

1. Escribir tests de integración para los flujos de usuario críticos
2. Implementar los widgets/vistas que reaccionan al estado del Controller
3. Conectar eventos de UI (tap, submit, timers) con funciones del Controller
4. Ejecutar tests de integración E2E y refactorizar hasta que todos pasen

**Validación**:

- ✅ Los flujos de usuario funcionan end-to-end (UI → Controller → Service → API → UseCase → Repository → DB → UI)
- ✅ Las interacciones producen los resultados esperados
- ✅ La UI refleja correctamente los estados (loading, success, error)
- ✅ Los casos de uso críticos están cubiertos

---