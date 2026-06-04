# MACSS API GraphQL CLI Specification (draft v0.3)

## 1. Proposito

Definir de forma cerrada y evolutiva como debe diseniarse el modulo `api` del
CLI `macss`, comenzando por su primera superficie fuerte: GraphQL artifact
tooling para `modular_api`.

Este documento se crea bajo enfoque spec-driven development.

Eso implica:
- primero se fija el contrato funcional y operativo
- despues se deriva el plan de implementacion
- la implementacion no debe adelantarse a decisiones no escritas aqui
- toda nueva decision relevante debe anotarse en esta spec o en una ADR ligada

Estado actual del documento:
- status: draft
- rama de trabajo: `spec/api-graphql-cli`
- foco actual: cerrar discoverability, precedencia de configuracion y contrato
  de salida del primer comando implementable, `macss api graphql compile`,
  dejando `check` y `schema` para iteraciones posteriores de la spec

---

## 2. Contexto

MACSS es el ecosistema raiz.

`modular_api` es un subsistema dentro de MACSS.

Por lo tanto, el companion CLI oficial del ecosistema no debe exponerse como un
binario principal `modular_api`, sino como el comando raiz `macss` con modulos.

Decisiones ya cerradas:
- el comando oficial top-level es `macss`
- los comandos globales viven en la raiz
- los subsistemas viven como modulos
- `modular_api` se expone bajo `macss api ...`
- GraphQL compile mode debe vivir bajo `macss api graphql ...`

Ejemplos de forma objetivo:
- `macss create --path=.`
- `macss doctor`
- `macss api graphql compile`
- `macss api graphql check`
- `macss api graphql schema`

---

## 3. Objetivo del modulo `api`

El modulo `api` sera la puerta de tooling del subsistema `modular_api` dentro
del companion CLI `macss`.

Responsabilidades esperadas a mediano plazo:
- tooling de compilacion y validacion GraphQL
- inspeccion de contratos y artefactos del API
- futuras automatizaciones alrededor de OpenAPI, build, release, y scaffold API

No debe asumir desde el inicio que GraphQL es la unica superficie del modulo.

Por eso se fija desde ahora una jerarquia de tres niveles:
- modulo: `api`
- superficie: `graphql`
- accion: `compile`, `check`, `schema`, etc.

Esto evita un comando demasiado plano como `macss api compile`, que seria
prematuro y ambiguo si en el futuro aparecen otras superficies del API.

---

## 4. Alcance de esta spec

Esta spec NO implementa todavia el modulo `api`.

Su alcance en esta etapa es:
- fijar el arbol de comandos del primer slice
- fijar la responsabilidad de cada comando
- fijar los principios de configuracion y output
- enumerar decisiones ya tomadas
- enumerar preguntas abiertas que deben cerrarse antes de codificar

Fuera de alcance en esta etapa:
- implementacion de codigo Dart del modulo `api`
- wiring real con `modular_api`
- parseo de flags definitivo
- lectura real de configuracion
- ejecucion real de compilacion GraphQL desde el CLI

---

## 5. Decisiones ya tomadas

### 5.1 Comando raiz

El binario oficial es `macss`.

No se crea un nuevo top-level CLI separado para `modular_api`.

### 5.2 Comando global vs modulo

`macss create --path=.` permanece como comando global porque opera sobre la
raiz del workspace o proyecto, no sobre un subsistema particular.

### 5.3 Modulo `api`

Se creara un modulo de primer nivel:
- `macss api ...`

### 5.4 Superficie GraphQL

La primera superficie fuerte dentro de `api` sera GraphQL.

Forma preferida:
- `macss api graphql compile`
- `macss api graphql check`
- `macss api graphql schema`

### 5.5 Relacion con `modular_api`

El modulo `api` es companion tooling para `modular_api`.

No reemplaza la libreria.
No reemplaza el runtime.
No reemplaza el package manager del SDK.

Su rol es tooling de desarrollo, build y CI/CD.

---

## 6. Principios de diseno del modulo `api`

1. Debe seguir la gramatica general del CLI MACSS:
   `macss <modulo> <superficie> <accion>`

2. Debe mantener separacion clara entre:
   - workspace-level workflows
   - subsystem-level workflows
   - leaf commands

3. Debe crecer por superficies explicitas y no por verbos ambiguos.

4. Debe ser compatible con CI/CD desde el primer slice util.

5. Debe ser consistente con el contrato de artefactos ya definido en
   `modular_api` para GraphQL v1.

6. Debe ser diseniado primero como contrato de tooling y despues como
   implementacion Dart.

---

## 7. Arbol de comandos objetivo inicial

Arbol inicial propuesto:

```text
macss
  help
  create
  doctor
  upgrade
  uninstall
  version
  api
    graphql
      compile
      check
      schema
```

Notas:
- `help` es una superficie explicita de discoverability del CLI
- `api` se reserva como namespace del subsistema `modular_api`
- `graphql` se reserva como namespace de la superficie GraphQL
- las acciones quedan al final
- `macss --help` y `macss -h` deben normalizarse a `macss help`

---

## 8. Intencion semantica de los primeros comandos

### 8.1 `macss api graphql compile`

Objetivo:
- ejecutar el compile mode oficial de GraphQL artifacts para `modular_api`

Resultado esperado:
- genera artefactos de salida bajo un directorio objetivo
- usa el pipeline de compilacion definido por `modular_api`
- produce como minimo:
  - `catalog.json`
  - `catalog.lock`
  - `diagnostics.json`
  - `schema.graphql`

Uso esperado:
- build local
- pre-commit manual
- CI/CD
- generacion de artifacts para despliegue

### 8.2 `macss api graphql check`

Objetivo:
- validar el estado del compile pipeline sin asumir que el usuario quiere
  persistir artefactos finales como paso principal

Posibles usos:
- validacion rapida en CI
- drift detection
- gate de diagnosticos antes de compilar o publicar

Nota:
- la semantica exacta de `check` sigue abierta y debe cerrarse antes de la
  implementacion

### 8.3 `macss api graphql schema`

Objetivo:
- exponer una vista ergonomica del SDL generado

Posibles usos:
- inspeccion humana
- export del schema sin consumir todos los artefactos como salida final
- debugging del compile mode

Nota:
- debe definirse si `schema` escribe archivo, imprime a stdout, o ambas cosas

---

## 9. Usuarios objetivo del primer slice

### 9.1 Desarrollador local

Quiere generar artifacts o validar que el contrato GraphQL sigue consistente
despues de cambiar SQL, metadata o configuracion.

### 9.2 Pipeline de CI

Quiere correr un comando estable, con exit codes predecibles, para fallar el
pipeline si el catalogo, el schema o los diagnosticos no cumplen contrato.

### 9.3 Maintainer del ecosistema

Quiere un companion tooling oficial que pertenezca a MACSS y no quede
fragmentado en binarios o comandos top-level ajenos al ecosistema raiz.

---

## 10. Decisiones cerradas en esta iteracion

Esta iteracion cierra el contrato de `macss api graphql compile`.

Queda decidido que, para el primer slice implementable:

1. `compile` sera el primer leaf command completamente especificado.
2. `compile` funcionara con convencion sobre configuracion, pero aceptando
   overrides explicitos por flags.
3. `compile` NO depende en su primer slice de un archivo de configuracion propio
   de MACSS.
4. `compile` debe poder ejecutarse dentro de un repo MACSS convencional y
   tambien fuera de MACSS si el usuario provee rutas explicitas.
5. `compile` tendra exit codes mas expresivos que el set minimo `0/1/2` del CLI
   global, porque su uso principal incluye CI/CD.
6. el CLI debe tener una superficie de discoverability explicita mediante
   `macss help`.
7. `macss --help` y `macss -h` deben normalizarse a `macss help`.
8. la precedencia de configuracion de `compile` incluye variables de entorno por
   debajo de los flags y por encima de las convenciones.
9. el comando debe separar salida humana y artefactos: los artefactos quedan en
   disco y la mensajeria humana va por `stderr`.
10. un archivo de configuracion de proyecto para este companion CLI queda como
    evolucion planificada posterior al slice `compile`, no como prerequisito de
    v1.

---

## 11. Contrato cerrado para `macss api graphql compile`

### 11.1 Sintaxis objetivo

Forma del comando:

```text
macss api graphql compile [--source-root=<dir>] [--metadata=<file>] [--output=<dir>] [--engine=<engine>]
```

No se definen aliases cortos en el primer slice.

Excepciones globales permitidas:
- `-h`
- `--help`

Motivo:
- priorizar legibilidad en CI y documentacion
- evitar colisiones prematuras entre modulos futuros
- mantener la forma explicita mientras el modulo `api` madura
- reservar `-v` para no mezclar prematuramente `version` con una posible nocion
  futura de `verbose`

### 11.1.1 Discoverability y ayuda

El companion CLI debe ofrecer una superficie de ayuda explicita y estable.

Contrato minimo:

- `macss help` muestra resumen global del CLI
- `macss --help` y `macss -h` se normalizan a `macss help`
- `macss help` debe listar comandos globales, modulos disponibles y ejemplos de
  uso
- `macss help` debe incluir al menos una referencia visible a
  `macss api graphql compile`
- `macss api graphql compile --help` debe mostrar uso y ejemplos del leaf
  command antes de la primera release del slice

Esta decision sigue el patron de CLIs modulares consolidados: una ayuda raiz
explicita y help contextual por leaf command.

### 11.2 Working directory y resolucion de rutas

El comando opera sobre el directorio actual del proceso.

Reglas:
- todas las rutas relativas se resuelven contra el current working directory
- el comando no realiza autodiscovery hacia directorios padres en v1
- si el usuario quiere compilar otro proyecto, debe ejecutar el comando desde
  ese proyecto o pasar flags explicitas con rutas adecuadas

Esto evita heuristicas magicas en el primer slice.

### 11.3 Regla de precedencia de configuracion

Para `compile`, la precedencia queda cerrada asi:

1. flags explicitas
2. variables de entorno
3. convenciones del repo/proyecto
4. defaults fijos del contrato

En el primer slice no existe un archivo de configuracion MACSS intermedio.

### 11.3.1 Variables de entorno del primer slice

Variables de entorno soportadas:

- `MACSS_API_GRAPHQL_SOURCE_ROOT`
- `MACSS_API_GRAPHQL_METADATA`
- `MACSS_API_GRAPHQL_OUTPUT`
- `MACSS_API_GRAPHQL_ENGINE`

Reglas:

- si existe flag explicita, la variable de entorno correspondiente se ignora
- si una variable de entorno de path usa ruta relativa, se resuelve contra el
  current working directory
- si no hay flag ni variable de entorno, aplican convenciones y luego defaults

Estas variables existen para CI/CD y para repos no convencionales que quieran
evitar repetir flags en cada invocacion.

### 11.4 Flags cerradas para el primer slice

Flags soportadas:

- `--source-root=<dir>`
- `--metadata=<file>`
- `--output=<dir>`
- `--engine=<engine>`

Semantica:

- `--source-root` define la raiz del arbol SQL gobernado
- `--metadata` define el sidecar de governance GraphQL
- `--output` define el directorio donde se escriben los artefactos
- `--engine` define el provider de ejecucion/compilacion

### 11.5 Defaults cerrados para el primer slice

Defaults:

- `sourceRoot` default: `code/db`
- `metadata` default: `<sourceRoot>/graphql.metadata.jsonc`
- `output` default: `.modular_api/graphql`
- `engine` default: `sqlserver`

Estas convenciones se apoyan en el contrato ya fijado en `modular_api`:
- metadata canonica: `<sourceRoot>/graphql.metadata.jsonc`
- `sourceRoot` tipico: `code/db`
- artifacts por defecto: `.modular_api/graphql`

### 11.6 Regla de engine en el primer slice

En el primer slice implementable, el unico engine aceptado es:
- `sqlserver`

Comportamiento:
- si el usuario omite `--engine`, se usa `sqlserver`
- si el usuario declara otro valor, el comando falla con invalid usage o config
  error segun el punto de validacion donde se detecte

`postgres` queda reservado para iteraciones futuras, pero no forma parte del
contrato implementable inicial.

### 11.7 Validacion de inputs resueltos

Antes de invocar el compilador, el comando debe validar:

1. que `sourceRoot` exista
2. que el archivo de metadata resuelto exista
3. que `engine` sea soportado por el slice actual
4. que el directorio de output pueda crearse o escribirse

El comando no debe depender de defaults invisibles no reportados al usuario.

### 11.8 Artefactos de salida obligatorios

`compile` debe escribir como salida autoritativa:

- `catalog.json`
- `catalog.lock`
- `diagnostics.json`
- `schema.graphql`

Reglas:
- `schema.graphql` siempre se emite en compile mode
- `catalog.lock` debe incluir como minimo:
  - `catalogVersion`
  - `sourceDigest`
  - `providerVersion`
- la salida debe ser estable y canonicamente ordenada para uso en diff de CI

### 11.9 Comportamiento ante diagnosticos bloqueantes

`compile` debe ser usable como paso de CI y como artefact writer.

Por eso se fija esta regla:

- si el pipeline logra producir el bundle de artefactos, debe escribirlos aun
  cuando existan diagnosticos de severidad `error`
- despues de escribirlos, el comando debe salir non-zero si existe al menos un
  diagnostico bloqueante

Esto deja evidencia material para inspeccion humana y debugging en CI.

### 11.10 Salida a consola del primer slice

La salida textual del primer slice debe ser corta, estable y util para CI.

### 11.10.1 Separacion de streams

Reglas cerradas:

- los artefactos autoritativos del comando viven en el filesystem, no en
  `stdout`
- la salida humana por defecto del comando debe ir a `stderr`
- en modo por defecto, `stdout` debe quedar vacio
- los mensajes de error esperables deben ser reescritos para humanos y no deben
  exponer stack traces por defecto

Esto mantiene composabilidad y deja libre `stdout` para una extension aditiva
futura de salida estructurada.

### 11.10.2 Contenido minimo de la salida humana

Minimo esperado:

1. resumen de configuracion resuelta
2. paths efectivos de sourceRoot, metadata y output
3. engine efectivo
4. resumen de diagnosticos por severidad
5. `sourceDigest` resultante cuando la compilacion llega a producir catalogo
6. path del archivo `diagnostics.json` cuando existan errores o warnings

`--json` queda reservado desde ahora para una futura salida estructurada por
`stdout` y NO debe reutilizarse con otro significado.

### 11.11 Exit codes cerrados para `compile`

Exit codes del primer slice:

- `0`: compilacion correcta, sin diagnosticos bloqueantes
- `2`: invalid usage (flags invalidas o combinacion invalida)
- `3`: config/convention resolution failure
- `4`: blocking diagnostics generated
- `5`: execution failure no atribuible a invalid usage ni diagnosticos

Interpretacion:
- `3` cubre casos como metadata faltante, sourceRoot inexistente o engine no
  soportado despues de resolver convenciones
- `4` significa que el pipeline produjo diagnosticos de error y los artefactos
  relevantes ya deberian existir en output
- `5` cubre IO error, parse crash, fallo inesperado del provider, etc.

### 11.12 Repos soportados por el primer slice

`compile` soporta dos modos de uso:

1. repo convencional MACSS/modular_api
2. repo no convencional con rutas explicitas

Esto significa:
- NO se exige que el usuario este en un repo MACSS
- SI se aprovechan defaults MACSS/modular_api cuando el layout coincide

### 11.13 Ejemplos de uso cerrados

Caso convencional dentro de un proyecto con layout esperado:

```text
macss api graphql compile
```

Caso con SQL fuera de `code/db`:

```text
macss api graphql compile --source-root=services/orders/db
```

Caso con metadata explicita:

```text
macss api graphql compile --source-root=services/orders/db --metadata=services/orders/db/graphql.metadata.jsonc
```

Caso con output explicito para pipeline:

```text
macss api graphql compile --output=artifacts/graphql
```

Caso CI orientado a drift review:

```text
macss api graphql compile --output=.modular_api/graphql
git diff --exit-code -- .modular_api/graphql
```

---

## 12. Preguntas abiertas que permanecen

Estas preguntas NO bloquean la especificacion de `compile`, pero si bloquean el
cierre completo del subarbol `graphql`.

### 12.1 Semantica exacta de `check`

Preguntas:
- valida y no escribe nada?
- valida y usa un directorio temporal?
- compara artifacts existentes contra una recompilacion?
- falla por warnings o solo por errores?

### 12.2 Semantica exacta de `schema`

Preguntas:
- imprime SDL a stdout?
- escribe `schema.graphql` en disco?
- hace ambas cosas con flags distintas?

### 12.3 Configuracion futura de MACSS

Preguntas:
- cual debe ser el nombre del futuro archivo de configuracion de proyecto?
- debe vivir en la raiz del repo o bajo un namespace propio de MACSS?
- cual debe ser su shape minima para no duplicar el contrato ya cubierto por
  flags y env vars?

---

## 13. Hipotesis de trabajo actual

Hipotesis principal actualizada:

El primer slice implementable del modulo `api` puede empezar por `macss api
graphql compile` sin reabrir el arbol de comandos, porque el contrato de
configuracion, defaults, output y exit codes ya quedo suficientemente cerrado.

Chequeo discriminante barato para esta hipotesis:

Si al escribir el plan TDD de `compile` aparece que el comando necesita un
archivo de configuracion antes de ser util, o que `sqlserver` no puede operar
con defaults convencionales razonables, o que la separacion `stderr/stdout`
requiere reestructurar el launcher de forma desproporcionada, entonces esta
iteracion de la spec aun no es suficiente.

---

## 14. Criterio de done de esta etapa de diseno

Esta etapa de spec-driven design se considera completa solo cuando:

- el arbol `macss api graphql ...` este cerrado
- el contrato de `compile` este definido sin ambiguedades
- la regla de precedencia de configuracion para `compile` este cerrada
- los outputs y exit codes de `compile` esten definidos
- exista base suficiente para escribir el plan TDD/implementacion de `compile`
  sin reabrir naming ni convenciones base

`check` y `schema` pueden quedar abiertos al cierre de esta etapa, siempre que
no bloqueen el inicio implementable de `compile`.

---

## 15. Siguiente paso recomendado

El siguiente paso recomendado es implementar el plan por etapas para
`macss api graphql compile`, empezando por discoverability, routing y
caracterizacion del framework antes del wiring con `modular_api`.

Ese plan ya debe cubrir:
- estructura de modulo `api`
- estructura de submodulo `graphql`
- discoverability (`help`, `-h`, `--help`)
- contrato Input/Output/Command
- precedencia de flags, env vars, convenciones y defaults
- invocacion del compilador de artifacts de `modular_api`
- manejo de exit codes y separacion `stderr/stdout`

Con eso, la implementacion ya puede arrancar sin reabrir la capa de diseno
principal.