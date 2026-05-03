# MACSS CLI v0.0.1 - Plan de desarrollo por etapas

## Objetivo

Construir la version v0.0.1 del CLI macss cumpliendo [docs/spec/cli_spec.md](c:/Users/44358590/Code/macss/macss/docs/spec/cli_spec.md), usando TDD como mecanismo principal de desarrollo.

Principios del plan:
- cada etapa comienza escribiendo tests que fallan
- cada etapa implementa el minimo codigo necesario para poner los tests en verde
- cada etapa termina con refactor pequeno y seguro
- no avanzar a la siguiente etapa con tests rojos de la etapa actual

Definicion de Done global:
- todos los comandos del alcance v0.0.1 implementados
- tests unitarios y de integracion relevantes en verde
- CI en Windows y Linux en verde
- release workflow capaz de publicar assets con binario + assets

---

## Etapa 0 - Bootstrap del paquete CLI

Objetivo:
- crear la estructura base compilable del paquete Dart con dependencias y separacion modular

Nota importante de orden:
El paquete debe existir y compilar ANTES de poder escribir tests. El TDD empieza en el
primer test ejecutable, no antes del bootstrap del package.

Paso 0.A — Crear el package (sin TDD aun):
- pubspec.yaml con dependencias exactas:
  - cli_router: ^0.0.3
  - modular_cli_sdk: ^0.2.1
  - path: ^1.9.1
  - yaml: ^3.1.3
  - dev: lints: ^6.1.0
  - dev: test: ^1.31.0
- analysis_options.yaml con `include: package:lints/recommended.yaml`
- bin/main.dart (entrypoint delgado, solo llama a runMacss y exit)
- lib/macss_cli.dart (registra modulo global con ModularCli)
- lib/modules/global/global_builder.dart (buildGlobalModule vacio)
- lib/assets.dart (clase Assets con path(), loadString(), capaz de recibir root en tests)

Paso 0.B — Primer test ejecutable (scaffold_test.dart):
Referencia: scaffold_test.dart en Inquiry.
1. Escribir test que verifique:
   - un comando registrado responde con exitCode 0
   - un comando desconocido responde con exitCode 64 (invalidUsage)
2. Verlo pasar con el registro minimo.

Inyeccion de Assets:
- `macss_cli.dart` resuelve `assetsRoot` desde `Platform.resolvedExecutable` y crea `Assets(root: assetsRoot)`
- lo pasa a `buildGlobalModule(m, assets: assets)`
- `global_builder.dart` lo recibe y lo inyecta en los comandos que lo necesitan (create, doctor)

Entregables:
- paquete CLI compilable con deps correctas
- lib/assets.dart
- scaffold_test.dart en verde

Validacion:
- dart pub get
- dart analyze
- dart test

---

## Etapa 1 - Versionado y fuente unica de version

Objetivo:
- establecer la fuente unica de version y su contrato

TDD:
1. Escribir test tipo [version_test.dart](c:/Users/44358590/Code/silicon-brained-machines/inquiry/code/cli/test/version_test.dart) que verifique:
	- `macss version` retorna la version actual
	- la version cumple semver
2. Escribir test de sincronizacion entre pubspec.yaml y lib/src/version.dart.
3. Implementar:
	- lib/src/version.dart
	- modules/global/commands/version.dart
4. Dejar los tests en verde.

Entregables:
- comando version
- version.dart como fuente unica
- test de sync de version

---

## Etapa 2 - TUI del comando raiz

Objetivo:
- implementar `macss` sin subcomando como banner/TUI informativa

TDD:
1. Escribir tests similares a [tui_test.dart](c:/Users/44358590/Code/silicon-brained-machines/inquiry/code/cli/test/tui_test.dart) para verificar:
	- exitCode 0
	- salida incluye version
	- salida incluye comandos disponibles
	- salida incluye alias ma
	- toText devuelve solo el bloque de salida formateado
2. Implementar modules/global/commands/tui.dart.
3. Ajustar formato hasta estabilizar snapshot textual.

Entregables:
- comando raiz macss
- tests de TUI

---

## Etapa 3 - Assets y plantillas del scaffold

Objetivo:
- crear los templates fisicos y verificar que Assets los resuelve correctamente en runtime y tests

TDD:
1. Escribir assets_test.dart que verifique:
   - Assets.path() resuelve rutas relativas bajo <root>/assets/
   - Assets.loadString() lee el contenido de un archivo de template
   - Assets.loadString() lanza FileSystemException para archivo inexistente
2. Crear templates minimos en assets/templates/project-base/:
   - docs/adr/0001-record-architecture-decisions.md
   - docs/architecture.md
   - docs/roadmap.md
3. Escribir tests de existencia de los 3 templates obligatorios usando un Assets real apuntando al directorio del paquete.

Contenido minimo de cada template:
- 0001-record-architecture-decisions.md: titulo + secciones Status/Context/Decision/Consequences
- architecture.md: titulo + secciones Modules/Layers/Cross-cutting concerns
- roadmap.md: titulo + secciones v0.0.1/v0.0.2/Backlog

Entregables:
- lib/assets.dart (ya creado en Etapa 0, tests ahora lo cubren completamente)
- assets/templates/project-base/ con los 3 templates
- assets_test.dart en verde

---

## Etapa 4 - Comando create con TDD de filesystem

Objetivo:
- implementar `macss create <path>` con comportamiento idempotente, copiando desde assets via Assets

TDD:
1. Escribir create_test.dart para:
   - crear en ruta relativa (directorio temporal como raiz)
   - crear en ruta absoluta
   - crear directorios code/db, code/api, code/ui
   - crear docs desde templates via Assets
   - contenido de archivo creado coincide con el template
   - no sobrescribir archivos existentes (comprobar que el contenido no cambia)
   - segunda ejecucion es idempotente (reporta exists, no crea de nuevo)
   - fallar con exitCode 2 si path apunta a un archivo existente (no a directorio)
   - fallar con error si path es cadena vacia
2. Implementar modules/global/commands/create.dart.
   - recibe Assets como dependencia (inyectado desde global_builder)
   - resolucion de ruta relativa/absoluta usando path package
3. Refactorizar si surgen utilidades compartidas de copia de templates.

Entregables:
- comando create
- create_test.dart en verde

Validacion:
- ejecutar solo el grupo de tests de create antes de continuar

---

## Etapa 5 - Comando doctor

Objetivo:
- verificar instalacion local y presencia de assets, similar a Inquiry

Nota:
doctor recibe Assets inyectado (no lo busca por su cuenta). El test usa Assets apuntando
a un directorio temporal para simular instalaciones completas y rotas sin tocar el sistema real.

TDD:
1. Escribir doctor_test.dart con MockFileSystemOps para:
   - caso OK: binario y los 3 templates presentes, exitCode 0
   - assets/ ausente: check falla con remediation
   - template ADR faltante: check falla con remediation
   - template architecture faltante: check falla con remediation
   - template roadmap faltante: check falla con remediation
   - salida textual (toText) resume checks con simbolos ok/error legibles
   - exitCode 1 si al menos un check falla
2. Implementar modules/global/commands/doctor.dart.
   - recibe Assets como dependencia (inyectado desde global_builder)
   - implementar FileSystemOps abstraction para hacer checks testeables sin tocar disco real

Entregables:
- comando doctor
- doctor_test.dart en verde

---

## Etapa 6 - Upgrade y chequeo de version remota

Objetivo:
- implementar `macss upgrade` con consulta a GitHub Releases y actualizacion por plataforma

TDD:
1. Escribir tests similares a [upgrade_test.dart](c:/Users/44358590/Code/silicon-brained-machines/inquiry/code/cli/test/upgrade_test.dart) para:
	- serializacion de input
	- salida cuando ya esta en latest
	- salida cuando hay upgrade
	- toText para casos con y sin update
2. Escribir tests unitarios para version_check.dart:
	- updateAvailable true cuando remote > current
	- false cuando remote == current
	- false ante fallo de red
3. Implementar:
	- lib/src/version_check.dart
	- lib/targets/platform_ops.dart
	- lib/targets/windows_platform_ops.dart
	- lib/targets/linux_platform_ops.dart
	- modules/global/commands/upgrade.dart

Entregables:
- upgrade funcional
- resolucion de assets por plataforma
- comparacion semver remota

---

## Etapa 7 - Uninstall seguro e idempotente

Objetivo:
- implementar `macss uninstall` con limpieza de PATH e instalacion

TDD:
1. Escribir tests similares a [uninstall_test.dart](c:/Users/44358590/Code/silicon-brained-machines/inquiry/code/cli/test/uninstall_test.dart) para:
	- limpiar instalacion existente
	- exit 0 cuando no hay nada instalado
	- quitar bin dir del PATH
	- no tocar PATH si no contiene bin dir
	- programar borrado diferido del directorio de instalacion
2. Implementar modules/global/commands/uninstall.dart.
3. Reusar PlatformOps para operaciones OS-specific.

Entregables:
- comando uninstall
- tests de limpieza de PATH y borrado diferido

---

## Etapa 8 - Scripts de instalacion

Objetivo:
- soportar instalacion local desde GitHub Releases en Windows y Linux

Nota de dependencia:
Los scripts solo pueden probarse end-to-end DESPUES de que exista un release real (Etapa 10).
En esta etapa se escribe y revisa el script; el smoke check final requiere un release publicado.

Rutas correctas de los scripts (igual que Inquiry):
- code/cli/scripts/install.ps1 (Windows)
- code/site/install.sh (Linux, servida desde el sitio web)
- code/cli/scripts/build.ps1 (compilacion local Windows)
- code/cli/scripts/build.sh (compilacion local Linux)
- code/cli/scripts/dev-install.ps1 (instalar desde fuente local Windows)
- code/cli/scripts/dev-install.sh (instalar desde fuente local Linux)

TDD:
1. Revisar que install.ps1 referencia repo correcto: ccisnedev/macss
2. Revisar que install.sh referencia asset correcto: macss-linux-x64.tar.gz
3. Revisar que ambos scripts:
   - instalan binario + carpeta assets (no solo el binario)
   - crean alias ma (ma.cmd en Windows, symlink en Linux)
   - verifican instalacion con macss version
4. Verificar que build.ps1 y build.sh empaquetan bin/ + assets/ igual que el release workflow.

Entregables:
- scripts de instalacion Windows/Linux
- scripts de build local
- scripts de dev-install

---

## Etapa 9 - CI

Objetivo:
- automatizar analisis y tests en Windows y Linux

TDD:
1. Crear `.github/workflows/ci.yml` siguiendo el patron de Inquiry.
2. Validar que el workflow cubre code/cli/**.
3. Ejecutar pruebas locales equivalentes antes de dar la etapa por cerrada.

Entregables:
- workflow CI operativo

---

## Etapa 10 - Release y empaquetado

Objetivo:
- publicar binarios descargables por release con assets incluidos

TDD:
1. Crear `.github/workflows/release.yml` con patron check-version -> create-release -> build.
2. Verificar que empaqueta:
	- macss-windows-x64.zip
	- macss-linux-x64.tar.gz
3. Verificar que el paquete contiene binario y carpeta assets.
4. Verificar que no libera si el tag ya existe.

Entregables:
- workflow release operativo
- assets de release definidos

---

## Etapa 10.5 - CHANGELOG y primer registro de version

Objetivo:
- inicializar CHANGELOG.md antes del gate final

TDD:
1. Crear CHANGELOG.md en code/cli/ siguiendo formato Keep a Changelog.
2. Escribir test de version_sync_test.dart que verifique:
   - version en pubspec.yaml coincide con version.dart
   No se sincroniza con sitio web en v0.0.1 (no hay code/site/ aun).
3. Añadir entrada para v0.0.1 con lista de comandos incluidos.

Entregables:
- code/cli/CHANGELOG.md con entrada inicial
- version_sync_test.dart en verde

---

## Etapa 11 - Gate final de v0.0.1

Objetivo:
- cerrar la entrega con una validacion completa del alcance

Checklist final:
- [ ] tests de scaffold (Etapa 0) en verde
- [ ] tests de version y sync (Etapa 1) en verde
- [ ] tests de TUI (Etapa 2) en verde
- [ ] tests de assets (Etapa 3) en verde
- [ ] tests de create (Etapa 4) en verde
- [ ] tests de doctor (Etapa 5) en verde
- [ ] tests de upgrade y version_check (Etapa 6) en verde
- [ ] tests de uninstall (Etapa 7) en verde
- [ ] dart analyze en verde (0 warnings, 0 errors)
- [ ] CI definido y pasando en Windows y Linux
- [ ] release workflow definido y capaz de publicar assets
- [ ] CHANGELOG.md inicializado con entrada de v0.0.1
- [ ] scripts de instalacion revisados y correctos

Resultado esperado:
- v0.0.1 implementable y publicable sin ambiguedades
