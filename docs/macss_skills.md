# MACSS Skills — Diseño y análisis

> **Superseded (2026-07-31).** The open questions in this draft are decided and
> shipped in 0.2.0. Read [ADR 0003](adr/0003-macss-owns-the-software-lifecycle.md)
> and Stage 5 of [the roadmap](roadmap.md) for the current design; this file is
> kept as the record of the analysis that led there.
>
> How the questions resolved:
>
> | Draft question | Decision |
> |---|---|
> | Where does `code/skills/` live? | Nowhere. Skills are assets under `code/cli/assets/skills/<name>/SKILL.md` |
> | Static or dynamic content? | **Static.** Hand-authored `SKILL.md`, not generated from repo inspection |
> | Deploy target per host? | Each assistant's own directory under `~/`, **once per machine**, not per repository. `macss skill deploy` refreshes every assistant it detects; `--host` targets one |
> | `--host` over `--target`? | Kept. `--host` is where the instruction runs |
> | Normative vs instructive skill | Deferred. What shipped is the **lifecycle** skill set — `macss-specification`, `macss-analyze`, `macss-plan`, `macss-execute` — one per stage, not one per audience |
>
> Only `claude` and `opencode` are offered, being the assistants whose skills
> directory convention is actually known. Guessing the others would create
> directories in a user's home that nothing reads.

Estado: superseded — ver el recuadro anterior
Última actualización del borrador: 2026-06-09

---

## Contexto

MACSS — Modular Architecture for Comprehensive Software Solutions

Una skill MACSS es un conjunto de instrucciones desplegadas en un AI assistant
(Claude, GitHub Copilot, Codex, Cursor) para que opere dentro de las convenciones
y restricciones de la arquitectura MACSS en un repositorio específico.

El despliegue se haría a través del CLI oficial:

```
macss skill deploy --host <assistant>
```

---

## Comando de despliegue

### Opción de flag: `--host`

Se eligió `--host` sobre `--target` por semántica: `--target` en CLIs suele
referirse a un artefacto de build. `--host` expresa dónde vive y corre la
instrucción — el AI assistant que va a interpretar la skill.

```
macss skill deploy --host claude
macss skill deploy --host copilot
macss skill deploy --host codex
macss skill deploy --host cursor
```

Cada host tiene un formato y path de archivo distintos, pero el contenido
MACSS es el mismo. El CLI hace la traducción al formato nativo de cada host:

| Host            | Archivo generado                          |
|-----------------|-------------------------------------------|
| claude          | `CLAUDE.md` o `.claude/` fragment         |
| copilot         | `.github/copilot-instructions.md`         |
| codex           | por definir (`.codex/` o system prompt)   |
| cursor          | `.cursor/rules/` o `.cursorrules`         |

---

## Dos skills con nombres distintos

La discusión reveló que hay dos audiencias con necesidades completamente
distintas. No son variantes de la misma skill — son skills con ciclos de
vida y propósitos separados.

---

### 1. Skill normativa — `macss`

**Audiencia:** desarrolladores en un repo que YA sigue MACSS.

**Propósito:** gobernar el comportamiento del AI assistant en ese repo.
Responde a: *¿qué puede y no puede hacer el AI aquí?*

**Características:**
- Repo-específica
- Host-dependiente en formato (no en contenido)
- Se actualiza cuando cambian las decisiones arquitectónicas del proyecto
- Es la skill por defecto

**Comando:**
```
macss skill deploy --host claude
```

---

### 2. Skill instructiva — `macss-guide` (nombre provisional)

**Audiencia:** desarrolladores aprendiendo MACSS o creando un proyecto desde cero.

**Propósito:** enseñar al AI cómo implementar siguiendo patrones MACSS.
Responde a: *¿cómo construyo esto?*

**Características:**
- Portable — el contenido no cambia por host
- Solo el mecanismo de inyección varía por host
- Se actualiza cuando evolucionan los patrones de implementación
- Cubre las combinaciones de stack soportadas

**Comando:**
```
macss guide deploy --host claude
```

**Alternativa de nombre:** `macss-cookbook`. Pendiente de decisión.

---

## Contenido de la skill normativa

La skill normativa tiene dos partes con orígenes distintos:

### Parte estática — reglas MACSS universales

Aplica a cualquier repo sin importar el stack. La genera `macss` desde
sus templates internos:

- No modificar contratos de aceptación sin aprobación humana explícita
- No reducir cobertura ni deshabilitar gates
- No introducir `skip/xfail` salvo política explícita
- Orden de capas: infra → db → api → app
- Bounded contexts explícitos — no imports directos entre módulos de negocio
- Fallos deben ser ruidosos — no swallow de excepciones sin `catchError`/`.catch`
- Cambios de contrato requieren actualizar pruebas de compatibilidad

### Parte dinámica — reglas específicas del repo

Solo las conoce el proyecto en el que se ejecuta el deploy:

- Qué DB usa este proyecto (postgres / sqlserver)
- Qué stack API (dart / typescript / python)
- Qué módulos existen y cuáles son sus fronteras
- Qué archivos son intocables (contratos, ADRs, tests de aceptación)
- Paths de ownership por capa

### Decisión de diseño pendiente (crítica)

¿Cómo obtiene el CLI la parte dinámica?

**Opción A — El CLI infiere leyendo el repo:**
El comando analiza `pubspec.yaml`, `package.json`, `pyproject.toml`,
estructura de carpetas, etc. y genera instrucciones contextuales.
- Pro: zero configuración para el desarrollador
- Contra: la inferencia puede ser incorrecta; el CLI se vuelve complejo

**Opción B — El desarrollador configura un `macss.yaml`:**
Existe un archivo de configuración en la raíz del repo que declara
el stack, los módulos y las fronteras.
- Pro: explícito, predecible, versionable
- Contra: fricción inicial; hay que mantenerlo sincronizado

**Opción C — Híbrido:**
El CLI infiere lo que puede y el `macss.yaml` sobreescribe o completa.
Equivalente a convention over configuration con escape hatch.

Esta decisión determina si `macss skill deploy` es un comando simple
(vuelca un template) o un comando inteligente (genera instrucciones
contextuales). Pendiente de decisión antes de implementar.

---

## Contenido de la skill instructiva

Cubre las combinaciones de stack soportadas por modular_api:

### Bases de datos
- PostgreSQL
- SQL Server

### APIs (SDKs modular_api)
- Dart
- TypeScript
- Python

### Frontend
- Flutter (preferido, con cliente multiplataforma verificado)
- Sin restricciones — cualquier frontend puede consumir la API REST/GraphQL

### Temas que debe cubrir la skill instructiva

- Cómo crear un módulo (estructura, DTO, use case)
- Cómo configurar la conexión a DB (postgres / sqlserver)
- Cómo definir un GraphQL catalog
- Cómo estructurar un handler REST
- Cómo escribir un test de aceptación Playwright para la UI
- Cómo publicar un paquete complementario (pub.dev, npm, PyPI)
- Cómo estructurar el monorepo con las capas MACSS

---

## Nombre de la skill — decisión tomada

La skill se llama **`macss`**, no `modular-api`.

Razones:
1. `modular api` es un término genérico — no es búscable ni registrable como marca
2. `macss` es único y diferenciador
3. La skill no es solo "cómo usar el paquete" — es la metodología completa
4. Para marketing: el contenido técnico (postgres + dart + flutter) es el argumento
   de venta; `macss` es lo que queda en la memoria y en los artículos

Tagline para contexto de presentación:
> MACSS — Modular Architecture for Comprehensive Software Solutions

---

## Skills de artefacto — `macss-commit` y `macss-pr`

Las skills existentes sirven **fases** (`analyze`, `plan`, `execute`). Estas dos
sirven **artefactos** producidos dentro de fases ya definidas, y no añaden
etapas al ciclo.

| Skill | Dónde se usa | Qué produce |
|---|---|---|
| `macss-commit` | implementation → execute | un commit que es una unidad lógica completa |
| `macss-pr` | delivery, y se retoca en verification | el título y el cuerpo de la PR |

**Por qué son skill y no comando.** Un comando sabe crear un commit; no sabe si
lo que está staged es una idea o son tres. Es la misma clase de juicio que hizo
que `implementation` se sirviera con skills desde el principio.

`macss-commit` lee lo que hay staged y responde una pregunta que el autor está
mal situado para responder sobre su propio trabajo: *¿esto es un solo cambio?*
Separa el refactor del cambio de comportamiento con el que viajó, se niega a
juntar un `fix` con un `feat`, y redacta el mensaje una vez la forma es
correcta. La disciplina no es estética: un commit que mezcla propósitos no se
puede revertir con precisión, y el refactor se esconde dentro del diff, donde la
review no lo va a cuestionar.

`macss-pr` importa por una razón que solo aparece cuando el release está
automatizado: con squash, **el título de la PR es el único mensaje que llega a
la rama principal**, y por tanto la única entrada del cálculo de versión.
Equivocarlo no produce un historial desprolijo — produce la versión equivocada,
o ningún release. La skill además avisa cuando la PR toca más de un componente
desplegable, porque eso sube la versión de todos los que toca.

Ambas son consecuencia de decisiones que viven en el handbook de la
organización que las consume ---Conventional Commits, SemVer, release-please,
squash obligatorio---. Las skills cargan la disciplina; no la inventan.

---

## Pendientes de diseño

- [ ] Diseñar `macss-commit`: detección de mezcla refactor/comportamiento, propuesta de troceo, redacción del mensaje
- [ ] Diseñar `macss-pr`: derivación de tipo y ámbito, aviso de PR multicomponente, cuerpo con la evidencia de verification
- [ ] Decidir nombre definitivo de la skill instructiva (`macss-guide` vs `macss-cookbook`)
- [ ] Decidir Opción A / B / C para la parte dinámica de la skill normativa
- [ ] Definir formato de `macss.yaml` si se elige Opción B o C
- [ ] Definir formato nativo para host `codex` (pendiente de investigar convención OpenAI)
- [ ] Definir si la skill instructiva va bajo `macss guide deploy` o como skill separada
- [ ] Diseñar estructura de `code/skills/` en el repositorio macss
- [ ] Decidir si las skills son templates estáticos o se generan dinámicamente
