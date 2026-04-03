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

**Capa**: Client — comunicación HTTP.

Clase que encapsula las llamadas HTTP al API del servidor. Existe uno por módulo (ej. `ClienteService`, `VentaService`). Usa `httpClient()` como abstracción de transporte.

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

**Capa**: Transversal — organización vertical.

Agrupación de casos de uso relacionados que pertenecen al mismo dominio de negocio. Un módulo atraviesa todas las capas (db, api, ui).

Ejemplos: módulo de Clientes, módulo de Ventas, módulo de Inventario.

**Regla clave**: fronteras explícitas y dependencias declaradas. Un módulo puede extraerse como microservicio sin cambiar su arquitectura interna.

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

Referencia abreviada a la clase Service que encapsula comunicación HTTP. No es una abstracción independiente — es el Service client en sí. Cuando la documentación dice "usa `httpClient()`", significa "usa la clase Service correspondiente para hacer la llamada HTTP".

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
