## Glosario MACSS

Definiciones precisas de los términos usados en la arquitectura. Cada término indica en qué capa opera y qué responsabilidad tiene.

---

### Interfaz (UI / CLI)

**Capa**: Client — presentación.

Componente visual (o textual en CLI) que muestra información al usuario y captura sus interacciones. No contiene lógica de negocio ni gestiona estado — delega ambas cosas al Controller.

**Origen**: En MVC (Smalltalk-80, Trygve Reenskaug, 1979), la View es la representación visual del Model. En MACSS, la Interfaz cumple ese rol: renderiza lo que el Controller le indica.

---

### Controller

**Capa**: Client — presentación.

Gestiona el estado de una vista y orquesta las llamadas entre la Interfaz y los Services. Cada vista tiene su propio Controller.

**Responsabilidades**:
- Recibir eventos de la Interfaz (tap, submit, input).
- Invocar al Service correspondiente.
- Mantener y exponer el estado de la vista (loading, data, error).
- Transformar datos para la presentación si es necesario.

**Origen**: En Smalltalk-80, el Controller manejaba input del usuario (teclado, mouse) y coordinaba la actualización entre Model y View. Era un componente de la **capa de presentación**. Frameworks web server-side (Rails, Spring MVC) reutilizaron el nombre para su capa de routing HTTP, pero eso ocurrió porque el servidor *generaba* la UI (server-side rendering). En una arquitectura donde API y UI están separadas, el Controller regresa a su lugar original: el cliente.

**En el servidor no existe Controller.** El routing HTTP + el UseCase cubren lo que un Controller de servidor haría. Agregar uno sería una capa pass-through sin responsabilidad propia.

---

### Service (Client)

**Capa**: Client — comunicación con el servidor.

Clase que encapsula las llamadas al servidor. Existe uno por módulo (ej. `ClienteService`, `VentaService`). Usa `ServiceClient` como abstracción de transporte — actualmente `HttpServiceClient` para commands (REST), futuro `GraphQLClient` para queries.

**Reglas**:
- No hay llamadas directas a APIs externas desde el cliente. Todo se canaliza a través de `api/`.
- La excepción es `/auth/` para autenticación, que puede tener una URL diferente pero sigue el mismo patrón.

**¿Por qué "Service"?** Porque comunica con un servicio HTTP remoto. El calificador de dominio (`ClienteService`, no `Service` a secas) satisface la regla de naming: el nombre es preciso sin contexto externo.

---

### Service (Server)

**Capa**: Server — comunicación con servicios externos.

Clase que encapsula llamadas HTTP a APIs de terceros desde el servidor (ej. `PaymentGatewayService`, `EmailDeliveryService`). Usa `httpClient()` como abstracción de transporte.

**Diferencia con Service (Client)**: el Service del cliente llama al API propio. El Service del servidor llama a servicios de terceros. Mismo patrón, diferente lado de la línea HTTP.

---

### API (HTTP Handler)

**Capa**: Server — transporte.

Servidor backend que expone endpoints HTTP. Su responsabilidad es exclusivamente de **transporte**: recibir un request HTTP, mapearlo al UseCase correspondiente, y devolver la respuesta como DTO.

**No contiene lógica de negocio.** Es mecánico: routing + middlewares + serialización.

**Equivalencia**: lo que en algunos frameworks se llama "HTTP Handler" o "Route Handler". En MACSS se usa "API" porque es el nombre natural de lo que expone: una interfaz programática.

---

### UseCase

**Capa**: Server — lógica de negocio.

Encapsula una operación de negocio completa. Expone una función `execute()` que recibe un DTO de input y devuelve un DTO de output.

**Responsabilidades**:
- Aplicar reglas de negocio.
- Orquestar llamadas a Repositories (datos) y Services (APIs externas).
- Coordinar transacciones cuando es necesario.

**Lo que NO hace**: parsear HTTP, serializar JSON, gestionar sesiones. Eso es responsabilidad del API layer.

**Origen**: Ivar Jacobson introdujo los Use Cases en OOSE (1992) como unidades de comportamiento del sistema desde la perspectiva del actor. En Clean Architecture (Robert C. Martin), los Use Cases son interactores que contienen las reglas de aplicación. MACSS adopta esta definición: un UseCase es una unidad atómica de lógica de negocio ejecutable y testeable de forma aislada.

---

### DTO (Data Transfer Object)

**Capa**: Transversal — contrato entre capas.

Objeto que define la estructura de datos de entrada (Input) y salida (Output) de un UseCase. Es un contrato explícito.

**Función `validate()`**: Cada DTO de input puede tener una función de validación que aplica reglas de negocio sobre los datos antes de que el UseCase los procese.

**Origen**: Martin Fowler / J2EE Core Patterns. Objeto cuyo único propósito es transportar datos entre procesos o capas, sin comportamiento propio (salvo validación de su propia integridad).

---

### Repository

**Capa**: Server — acceso a datos.

Clase que ejecuta queries SQL contra la base de datos y mapea resultados a entidades del dominio. Es la frontera entre la lógica de negocio y la persistencia.

**Reglas**:
- Escribe SQL directamente (no ORM). Coherente con el principio Database as Code.
- Un Repository encapsula las operaciones de una entidad o agregado.
- El UseCase consume Repositories, nunca accede a la DB directamente.

**Origen**: Eric Evans, Domain-Driven Design (2003). Un Repository proporciona la ilusión de una colección en memoria de objetos del dominio, encapsulando la lógica de acceso a datos.

---

### Módulo

**Capa**: Interna a cada capa — organización por dominio.

Agrupación de casos de uso relacionados que pertenecen al mismo dominio de negocio, **dentro de una capa específica**. Cada capa (db, api, app, cli) organiza su código en módulos.

Ejemplos: `api/modules/customers/`, `db/modules/customers/`, `app/modules/customers/`.

**Regla clave**: fronteras explícitas y dependencias declaradas con otros módulos de la misma capa. Un módulo no es cross-layer — es la unidad organizativa *dentro* de una capa.

**Relación con Slice**: los módulos homónimos de distintas capas forman un slice.

---

### Slice (rebanada)

**Capa**: Transversal — concepto mental, no artefacto físico.

La unión lógica de los módulos que comparten un dominio de negocio a través de todas las capas. Un slice corta transversalmente el sistema como una rebanada corta un pastel de capas.

```
slice "payments" = db/modules/payments + api/modules/payments + app/modules/payments
```

**No es una carpeta.** Es una restricción de coherencia: si existe un módulo `X` en `api/`, debe existir su contraparte en `db/`. La convención de nombres iguales es lo que materializa el slice.

**Propiedad clave**: un slice puede extraerse como microservicio sin cambiar su arquitectura interna — se toma la rebanada completa (todos los módulos homónimos) y se despliega de forma independiente.

**Metáfora**: Le Corbusier llamó *cellule* a la unidad mínima habitable de la Unité d'Habitation. En MACSS, el slice es la *cellule* — la unidad mínima funcional completa de una solución integral de software.

---

### Middleware

**Capa**: Server — transporte (cross-cutting).

Función que se ejecuta antes o después de un HTTP Handler. Implementa concerns transversales: auth, CORS, logging, rate limiting, validación de headers.

**No contiene lógica de negocio.** Opera a nivel de transporte HTTP.

---

### Database as Code

**Capa**: Persistencia.

Enfoque declarativo para gestionar esquemas de base de datos mediante scripts DDL versionados, en lugar de migraciones incrementales o ORMs.

**Herramientas**:
- **SQL Server**: `sqlpackage` — compara el estado deseado (scripts) con el estado actual y genera el plan de cambios.
- **PostgreSQL**: `pgschema` — gestión declarativa de esquemas.

**Principio**: el esquema de la base de datos es código fuente. Se versiona, se revisa en PR, se aplica de forma reproducible.

---

### `httpClient()`

**Capa**: Transversal — azúcar sintáctico.

Función de conveniencia para llamadas HTTP de un solo uso (one-shot). Internamente crea un `ServiceClient` temporal, envía el request y cierra la conexión. Es azúcar sintáctico sobre la clase `ServiceClient` del package `service_client`.

Cuando la documentación dice "usa `httpClient()`", significa "usa el service client para hacer la llamada HTTP". La implementación real vive en el package `service_client` (actualmente Dart, futuro TS y Python).

---

### `usecaseTestHandler()`

**Capa**: Testing.

Herramienta para probar UseCases de forma aislada. Proporciona un entorno controlado donde se pueden mockear Repositories y Services para validar exclusivamente la lógica de negocio del UseCase.

---

### OpenAPI

**Capa**: Contrato entre client y server.

Especificación que define el contrato HTTP del API: endpoints, métodos, DTOs de request/response, códigos de error. Es la fuente de verdad para la comunicación entre client y server.

**En MACSS**: reemplaza la necesidad de un package de dominio compartido. Client y server pueden estar en lenguajes diferentes — OpenAPI es el contrato agnóstico que los sincroniza.

---

### Event Bus / Cola

**Capa**: Server — comunicación asíncrona.

Canal de comunicación entre UseCases que opera de forma asíncrona. Un UseCase productor publica un evento; uno o más UseCases consumidores reaccionan.

Puede ser in-process (mismo servidor) o distribuido (RabbitMQ, Kafka, etc.).

---

### Gate

**Capa**: Proceso — verificación.

Punto de verificación automática que debe pasar antes de considerar un cambio como completo. Incluye: tests (unit, contract, integration, e2e), lint, format, typecheck, seguridad, performance.

**En MACSS**: los gates son el "sensor" del lazo cerrado. La AI itera hasta que todos los gates pasen.

---

### CQRS (Command Query Responsibility Segregation)

**Capa**: Transversal — principio arquitectónico.

Separación estructural entre operaciones de escritura (Commands) y operaciones de lectura (Queries). En MACSS, la separación no es convencional sino de protocolo:

- **Commands** → REST/HTTP (POST, PUT, PATCH, DELETE). Cada endpoint es un UseCase que muta estado.
- **Queries** → GraphQL. El cliente solicita exactamente los campos que necesita. Los resolvers son UseCases GET.

**Origen**: Greg Young formalizó CQRS como patrón en 2010, separando los modelos de lectura y escritura. MACSS lo adopta a nivel de transporte: commands y queries fluyen por protocolos distintos, con validaciones distintas y contratos distintos (OpenAPI vs GraphQL Schema).

---

### Command

**Capa**: Server — operación de escritura.

Un UseCase que muta estado. Se expone como endpoint REST (POST, PUT, PATCH, DELETE). Tiene validación estricta via `validate()` + Input DTO. Retorna un Output DTO con el resultado de la operación.

En el contexto CQRS de MACSS, los Commands son la mitad de escritura del sistema.

---

### Query

**Capa**: Server — operación de lectura.

Un UseCase GET que lee datos sin mutar estado. Se expone tanto como endpoint REST como resolver GraphQL (via plugin). El plugin GraphQL solo monta UseCases GET — nunca commands.

En el contexto CQRS de MACSS, las Queries son la mitad de lectura del sistema. GraphQL permite al cliente solicitar exactamente los campos que necesita.

---

### GraphQL (en MACSS)

**Capa**: Server — transporte de lectura.

Capa de lectura auto-generada por el plugin `modular_api_graphql`. No se escribe manualmente — el plugin detecta los UseCases GET registrados, genera un tipo GraphQL por cada Output, y los expone como queries.

**Reglas**:
- GraphQL solo sirve queries (lectura). Las mutaciones no existen en MACSS — los commands usan REST.
- Los resolvers llaman al UseCase internamente, respetando `validate()`, logging y métricas.
- El schema se genera automáticamente desde los DTOs, igual que OpenAPI.

**En el cliente**: el `ServiceClient` tendrá un `GraphQLClient` que envía queries como HTTP POST a `/graphql` con `{ "query": "...", "variables": {...} }`. No requiere librerías GraphQL pesadas.
