*Modular arquitecture for comprehensive software solutions*

Metodología/framework para desarrollo basada en: **arquitectura modular**, **especificación ejecutable** (tests/contratos) y **lazo cerrado** (verificación automática como sensor de error). Tiene la ventaja de ser favorable para desarrollo asistido por AI.

---
## Arquitectura de capas
---

```mermaid
sequenceDiagram
		actor U as Usuario
		box client
		participant UI as Interfaz
		participant C as Controller
		participant S as Service
		end
		box server
		participant API as API
		participant UC as UseCase
		participant REPO as Repository
		end
		box database
		participant DB as DB
		end

		U-->>UI: Interacción
		UI->>C: Evento
		C->>S: Llamada a Service
		S-->>API: HTTP Request
		API->>UC: Mapea a UseCase
		UC->>REPO: Consulta/Comando
		REPO-->>DB: Query SQL
		DB-->>REPO: Resultados
		REPO->>UC: Entidades
		UC->>API: Response DTO
		API-->>S: HTTP Response
		S->>C: Data/Error
		C->>UI: Actualiza estado
		UI-->>U: Muestra resultado
```

### Capas

- **interfaz**: Interfaz de usuario (UI o CLI) que presenta información y captura interacciones del usuario.
- **Controller**: Gestiona el estado de la aplicación y orquesta las llamadas entre la interfaz y los servicios.
- **Service (App)**: Capa de comunicación HTTP entre la aplicación cliente y el backend.
- **API**: Servidor backend que expone endpoints y coordina la ejecución de casos de uso.
- **UseCase**: Encapsula la lógica de negocio y coordina operaciones entre repositorios y servicios externos.
- **Repository**: Capa de acceso a datos que ejecuta consultas y comandos SQL.
- **DB**: Sistema de persistencia (SQL).
