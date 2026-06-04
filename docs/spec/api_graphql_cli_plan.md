# MACSS API GraphQL CLI - Plan de implementacion por etapas

## Objetivo

Implementar el primer slice productivo del modulo `api` del CLI `macss`:

```text
macss api graphql compile
```

Este plan deriva de la spec `api_graphql_cli_spec.md` y asume que el contrato
de `compile` ya esta cerrado para:
- flags
- defaults
- precedencia de configuracion
- variables de entorno soportadas
- artifacts obligatorios
- discoverability del comando
- salida textual minima y separacion de streams
- exit codes `0`, `2`, `3`, `4`, `5`

---

## Principios de ejecucion

Reglas del plan:
- cada etapa empieza en rojo con uno o mas tests nuevos
- cada etapa implementa solo el minimo codigo necesario para poner esos tests
  en verde
- cada etapa termina con refactor pequeno y seguro
- no se avanza con tests rojos de la etapa actual
- primero se estabilizan tests unitarios de contrato y despues se agregan
  pruebas de integracion
- cuando una dependencia publica aun no existe, el rojo inicial puede ser de
  compilacion; eso sigue contando como TDD si el test fue escrito primero

Regla de validacion:
- despues del primer cambio sustantivo de cada etapa, correr el test enfocado de
  esa etapa antes de seguir editando

Regla adicional de ingenieria:
- antes de asumir como `modular_cli_sdk` maneja ayuda, streams o errores,
   escribir una caracterizacion puntual y hacer que el plan dependa de ese
   resultado en lugar de adivinarlo

---

## Riesgo tecnico principal ya identificado

El paquete `macss_cli` aun no puede construir el pipeline completo de GraphQL
artifacts usando solo superficie publica de `modular_api`.

Hoy `modular_api` expone publicamente:
- `GraphqlArtifactCompiler`
- `GraphqlArtifactBundle`
- `GraphqlArtifactCompileError`
- `GraphqlCatalogFactory`

Pero no expone aun, de forma publica y ergonomica, un puente que convierta:
- `sourceRoot`
- `metadataFile`
- `engine`

en un `GraphqlCatalogFactory` listo para el CLI.

Por eso este plan reserva una etapa upstream especifica en `modular_api`.

Regla de arquitectura:
- `macss_cli` NO debe importar rutas `src/` privadas de `modular_api`

---

## Definicion de Done global

El slice se considera completo solo cuando:
- `macss help`, `macss --help` y `macss -h` funcionan
- `macss help` expone `api graphql compile`
- `macss api graphql compile --help` funciona
- `macss api graphql compile` esta registrado y documentado
- funciona con layout convencional sin flags
- funciona con overrides explicitos de `source-root`, `metadata` y `output`
- funciona con variables de entorno cuando no hay flags explicitas
- escribe `catalog.json`, `catalog.lock`, `diagnostics.json` y
  `schema.graphql`
- devuelve exit code `4` cuando existen diagnosticos bloqueantes y deja los
  artifacts escritos si el bundle pudo producirse
- devuelve `2`, `3` y `5` en las clases de error correctas
- emite salida humana por `stderr` y no usa `stdout` en modo por defecto
- los tests unitarios e integracion del paquete CLI estan en verde
- la etapa upstream necesaria en `modular_api` esta en verde

---

## Etapa 0 - Discoverability y routing inicial

Objetivo:
- crear el arbol minimo de modulos, la superficie de ayuda y registrar el leaf
  command `compile`

TDD:
1. Escribir `code/cli/test/api_graphql_scaffold_test.dart` para verificar:
   - `api graphql compile` deja de ser comando desconocido
   - `api graphql unknown` sigue fallando como comando desconocido
   - el comando `compile` existente responde con una salida de placeholder o con
     un fallo controlado, pero no con error de routing
2. Escribir `code/cli/test/help_command_test.dart` para verificar:
   - `macss help` muestra comandos globales y modulos
   - `macss help` incluye `api graphql compile`
   - `normalizeMacssArgs(['--help'])` produce `['help']`
   - `normalizeMacssArgs(['-h'])` produce `['help']`
3. Ver el rojo inicial por falta de help/routing.
4. Implementar el minimo wiring en:
   - `code/cli/lib/modules/global/commands/help.dart`
   - `code/cli/lib/modules/global/global_builder.dart`
   - `code/cli/lib/modules/api/api_builder.dart`
   - `code/cli/lib/modules/api/graphql/graphql_builder.dart`
   - `code/cli/lib/modules/api/graphql/commands/compile.dart`
   - `code/cli/lib/macss_cli.dart`
5. Refactor pequeno si hace falta para mantener el mismo patron usado por el
   modulo global.

Entregables:
- comando global `help`
- modulo `api`
- submodulo `graphql`
- comando `compile` registrado
- normalizacion top-level de `-h` y `--help`

Validacion enfocada:
- `dart test test/api_graphql_scaffold_test.dart`
- `dart test test/help_command_test.dart`

---

## Etapa 1 - Caracterizar framework, ayuda y streams

Objetivo:
- fijar con tests como `modular_cli_sdk` y `cli_router` propagan `validate()`,
  `exitCode`, `toText()`, ayuda y streams para no adivinar la estrategia de
  errores ni de salida

TDD:
1. Escribir `code/cli/test/api_graphql_command_contract_test.dart` con comandos
   dummy para verificar:
   - que pasa cuando `validate()` devuelve un mensaje
   - si `Output.exitCode` preserva valores custom como `3`, `4` y `5`
   - como se refleja `toText()` en el flujo normal del comando
   - como se debe servir `compile --help` en el framework actual
2. Escribir `code/cli/test/api_graphql_stream_contract_test.dart` para
   verificar, preferiblemente via launcher/integracion minima:
   - por que stream sale la salida por defecto del comando
   - si hace falta un adapter propio para cumplir el contrato `stderr/stdout`
3. Ver el rojo inicial.
4. Implementar solo el harness minimo del test si hace falta.
5. Documentar dentro del mismo test la estrategia operativa resultante:
   - `validate()` se usara solo para invalid usage estrictamente sintactico
   - los errores de resolucion/configuracion viviran en `execute()` para poder
     mapearlos a `3`, `4` y `5`
   - si `compile --help` se resuelve nativamente o via ayuda explicita del
     modulo
   - si la separacion `stderr/stdout` requiere wrapper del launcher

Entregables:
- caracterizacion estable del contrato del framework
- decision testeada sobre donde resolver cada clase de error
- decision testeada sobre ayuda contextual y streams

Validacion enfocada:
- `dart test test/api_graphql_command_contract_test.dart`
- `dart test test/api_graphql_stream_contract_test.dart`

---

## Etapa 2 - Input crudo y resolucion de configuracion

Objetivo:
- modelar el input del comando y resolver defaults/overrides exactamente como
  dice la spec

TDD:
1. Escribir `code/cli/test/api_graphql_compile_input_test.dart` para verificar:
   - parseo de `--source-root`
   - parseo de `--metadata`
   - parseo de `--output`
   - parseo de `--engine`
   - captura del current working directory
2. Escribir `code/cli/test/api_graphql_compile_config_resolver_test.dart` para
   verificar:
   - default `sourceRoot = code/db`
   - default `metadata = <sourceRoot>/graphql.metadata.jsonc`
   - default `output = .modular_api/graphql`
   - default `engine = sqlserver`
   - variables de entorno resueltas cuando no hay flags
   - flags explicitas pisan variables de entorno
   - flags explicitas pisan defaults
   - rutas relativas se resuelven contra el current working directory
3. Ver rojo por ausencia de modelos y resolver.
4. Implementar el minimo codigo en:
   - `code/cli/lib/modules/api/graphql/commands/compile.dart`
   - `code/cli/lib/src/api/graphql/compile_input.dart`
   - `code/cli/lib/src/api/graphql/compile_config.dart`
   - `code/cli/lib/src/api/graphql/compile_config_resolver.dart`
5. Refactorizar helpers de paths si aparecen duplicaciones.

Entregables:
- `GraphqlCompileInput`
- `GraphqlCompileResolvedConfig`
- resolver de flags, env vars, convenciones y overrides

Validacion enfocada:
- `dart test test/api_graphql_compile_input_test.dart`
- `dart test test/api_graphql_compile_config_resolver_test.dart`

---

## Etapa 3 - Validacion previa y taxonomia de fallos

Objetivo:
- separar invalid usage, config failure y execution failure antes de integrar el
  compilador real

TDD:
1. Escribir `code/cli/test/api_graphql_compile_validation_test.dart` para
   verificar:
   - `--engine` distinto de `sqlserver` falla como invalid usage con exit `2`
   - `sourceRoot` inexistente falla con exit `3`
   - metadata inexistente falla con exit `3`
   - no se intenta invocar el compilador si la validacion previa falla
2. Ver rojo.
3. Implementar el minimo codigo en:
   - `code/cli/lib/src/api/graphql/compile_validation.dart`
   - `code/cli/lib/modules/api/graphql/commands/compile.dart`
4. Introducir una pequena taxonomia interna, por ejemplo:
   - `GraphqlCompileUsageError`
   - `GraphqlCompileConfigError`
5. Refactorizar solo si mejora la legibilidad del mapping de exit codes.

Entregables:
- validacion previa consistente con la spec
- mapping estable para `2` y `3`

Validacion enfocada:
- `dart test test/api_graphql_compile_validation_test.dart`

---

## Etapa 4 - Abrir el puente publico en `modular_api`

Objetivo:
- exponer una API publica minima para que `macss_cli` pueda compilar artifacts
  sin importar internals privados de `modular_api`

Nota:
Esta etapa vive en el repo `modular_api`, pero es prerequisito tecnico del CLI.

TDD:
1. Escribir un test rojo en Dart dentro de `modular_api` para una superficie
   publica minima, por ejemplo una de estas dos formas:
   - una funcion `compileGraphqlArtifacts(...)`
   - un adapter/builder publico que cree el `GraphqlCatalogFactory` desde
     `sourceRoot`, `metadataFile` y `engine`
2. Ver rojo por API inexistente.
3. Implementar el minimo codigo upstream y exportarlo desde
   `code/dart/lib/modular_api.dart`.
4. Mantener el alcance minimo:
   - solo `sqlserver`
   - solo compile mode
   - sin adelantar `check` ni `schema`
5. Refactor pequeno una vez verde.

Entregables:
- superficie publica upstream consumible por `macss_cli`
- test contractual verde en `modular_api`

Validacion enfocada:
- test Dart puntual de la nueva API en `modular_api`

---

## Etapa 5 - Runner del comando con fake upstream

Objetivo:
- integrar el comando CLI contra una abstraccion de runner antes de usar la
  implementacion real de `modular_api`

TDD:
1. Escribir `code/cli/test/api_graphql_compile_command_test.dart` para
   verificar, usando un fake runner:
   - el comando pasa al runner el `sourceRoot` resuelto
   - el comando pasa al runner el `metadataFile` resuelto
   - el comando pasa al runner el `outputDirectory` resuelto
   - el comando pasa el engine efectivo `sqlserver`
   - el comando devuelve `0` cuando el runner reporta exito sin errores
2. Ver rojo.
3. Implementar el minimo codigo en:
   - `code/cli/lib/src/api/graphql/compile_runner.dart`
   - `code/cli/lib/modules/api/graphql/commands/compile.dart`
4. Mantener inyeccion explicita del runner para que la mayor parte del comando
   siga cubierta por tests unitarios.

Entregables:
- `GraphqlCompileRunner` o equivalente
- comando aislado del upstream real en tests unitarios

Validacion enfocada:
- `dart test test/api_graphql_compile_command_test.dart`

---

## Etapa 6 - Wiring real con `modular_api` y politica de escritura

Objetivo:
- conectar el runner real al puente publico upstream y fijar la semantica de
  escritura de artifacts

TDD:
1. Escribir `code/cli/test/api_graphql_compile_runner_test.dart` para
   verificar, con filesystem temporal y el runner real:
   - se crean `catalog.json`, `catalog.lock`, `diagnostics.json` y
     `schema.graphql`
   - `schema.graphql` siempre queda escrito
   - `catalog.lock` contiene `catalogVersion`, `sourceDigest` y
     `providerVersion`
   - el output directory se crea si no existe
2. Escribir un segundo test para el caso de diagnosticos bloqueantes:
   - los artifacts se escriben igualmente si el bundle fue producido
   - el resultado final del comando es exit `4`
3. Ver rojo.
4. Implementar el runner real y el mapping de `GraphqlArtifactCompileError`.
5. Refactorizar separando claramente:
   - construccion del request upstream
   - invocacion del compilador
   - interpretacion del resultado

Entregables:
- runner real conectado a `modular_api`
- politica de escritura alineada con compile mode
- mapping estable de exit `4`

Validacion enfocada:
- `dart test test/api_graphql_compile_runner_test.dart`

---

## Etapa 7 - Salida textual y snapshots de DX

Objetivo:
- estabilizar una salida corta, legible y util para CI/CD, cumpliendo la
   separacion de streams fijada por la spec

TDD:
1. Escribir `code/cli/test/api_graphql_compile_output_test.dart` para
   verificar que `toText()` o la salida equivalente incluya:
   - resumen de configuracion resuelta
   - `sourceRoot`, `metadata` y `output` efectivos
   - engine efectivo
   - resumen de diagnosticos por severidad
   - `sourceDigest` cuando exista
   - path de `diagnostics.json` cuando haya warnings o errores
2. Escribir `code/cli/test/api_graphql_compile_streams_test.dart` para
   verificar:
   - la salida humana por defecto va a `stderr`
   - `stdout` queda vacio en modo por defecto
   - los errores esperables no emiten stack trace por defecto
3. Escribir snapshots textuales separados para:
   - exito limpio
   - diagnosticos bloqueantes
   - config failure
4. Ver rojo.
5. Implementar el minimo codigo en:
   - `code/cli/lib/src/api/graphql/compile_output.dart`
   - `code/cli/lib/src/api/graphql/compile_report_formatter.dart`
   - `code/cli/lib/modules/api/graphql/commands/compile.dart`
6. Refactorizar formato solo despues de congelar snapshots.

Entregables:
- salida textual estable
- snapshots que protegen la DX del comando
- separacion `stderr/stdout` cubierta por tests

Validacion enfocada:
- `dart test test/api_graphql_compile_output_test.dart`
- `dart test test/api_graphql_compile_streams_test.dart`

---

## Etapa 8 - Integracion end-to-end con layout convencional

Objetivo:
- demostrar que el comando funciona sin flags dentro de un repo con layout
  convencional

TDD:
1. Crear fixture minima de proyecto con:
   - `code/db/...`
   - `code/db/graphql.metadata.jsonc`
   - contenido minimo necesario para producir artifacts
2. Escribir `code/cli/test/api_graphql_compile_integration_test.dart` para
   ejecutar el CLI end-to-end y verificar:
   - exit `0` en caso limpio
   - artifacts creados en `.modular_api/graphql`
   - contenido no vacio de `schema.graphql`
3. Ver rojo.
4. Implementar solo los ajustes finales de wiring que falten.
5. Refactor pequeno si se detecta codigo duplicado entre command test e
   integration test.

Entregables:
- prueba end-to-end del happy path convencional

Validacion enfocada:
- `dart test test/api_graphql_compile_integration_test.dart`

---

## Etapa 9 - Integracion end-to-end con overrides y fallos reales

Objetivo:
- cubrir el resto del contrato visible para usuario y CI

TDD:
1. Ampliar `code/cli/test/api_graphql_compile_integration_test.dart` o crear un
   archivo especifico para verificar:
   - `--source-root` explicito fuera de `code/db`
   - `--metadata` explicito
   - `--output` explicito
   - metadata faltante => exit `3`
   - source root faltante => exit `3`
   - engine invalido => exit `2`
   - fallo inesperado del runner => exit `5`
2. Ver rojo por los casos faltantes.
3. Implementar el minimo ajuste restante.
4. Refactorizar helpers de fixture/paths.

Entregables:
- contrato end-to-end completo para success y errores visibles

Validacion enfocada:
- `dart test test/api_graphql_compile_integration_test.dart`

---

## Etapa 10 - Endurecimiento final

Objetivo:
- cerrar el slice con validacion completa y preparar el terreno para `check` y
  `schema` sin implementarlos aun

TDD:
1. Agregar solo los tests faltantes descubiertos durante integracion, sin abrir
   nuevas superficies funcionales.
2. Ver rojo si aun queda algun hueco contractual.
3. Implementar el minimo cierre pendiente.

Checklist final de validacion:
- `dart test` del paquete CLI completo
- `dart analyze` del paquete CLI
- test puntual upstream en `modular_api`
- test de ayuda global y contextual en verde
- test de streams en verde
- si existe CI del repo, dejar lista la ejecucion del paquete CLI en Windows y
  Linux

Entregables:
- slice `compile` listo para merge
- base limpia para abrir luego las specs/planes de `check` y `schema`

---

## Orden recomendado de ejecucion

Orden estricto recomendado:

1. Etapa 0
2. Etapa 1
3. Etapa 2
4. Etapa 3
5. Etapa 4
6. Etapa 5
7. Etapa 6
8. Etapa 7
9. Etapa 8
10. Etapa 9
11. Etapa 10

No conviene saltar la Etapa 4.

Si el puente publico de `modular_api` no existe, cualquier wiring directo desde
`macss_cli` hacia imports privados seria deuda tecnica estructural desde el
primer merge.

---

## Criterio para abrir la siguiente spec

La spec de `macss api graphql check` y `macss api graphql schema` deberia abrirse
solo despues de que este plan termine o despues de que, como minimo, las etapas
0 a 7 esten en verde.

Eso garantiza que:
- el namespace `api/graphql` ya esta estabilizado
- la politica de output y exit codes de `compile` ya esta fijada por codigo
- el companion CLI ya tiene un camino probado para integrarse con
  `modular_api`