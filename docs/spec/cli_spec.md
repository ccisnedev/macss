# MACSS CLI Specification (v0.0.1)

## 1. Proposito

Definir de forma cerrada y sin ambiguedades como construir la version v0.0.1 del CLI macss.

Alcance estricto de v0.0.1:
- macss (banner/TUI informativa)
- macss create <path>
- macss doctor
- macss uninstall
- macss upgrade
- macss version

Tambien incluye requisitos minimos de distribucion:
- descarga de nuevas versiones desde GitHub Releases
- CI y release/deploy similares a Inquiry

---

## 2. Alcance funcional de v0.0.1

### 2.1 Comandos incluidos

1. macss
2. macss create <path>
3. macss doctor
4. macss uninstall
5. macss upgrade
6. macss version

### 2.2 Comandos fuera de alcance

- seleccion interactiva de stack (db/api/ui)
- comandos de target/deploy de agentes
- generadores tecnologicos por stack (ts/dart/py/flutter)

Todo lo fuera de alcance queda para v0.0.2+.

---

## 3. Convenciones de implementacion (referencia Inquiry)

Se adopta la misma filosofia modular usada en Inquiry:

1. Entrypoint delgado en bin/main.dart.
2. Punto unico de arranque en libreria publica (runMacss).
3. Registro por modulo (global) con ModuleBuilder.
4. Cada comando con Input, Output, Command.
5. Separacion estricta validate() y execute().

Estructura objetivo:

```text
code/cli/
	bin/
		main.dart
	lib/
		macss_cli.dart
		src/
			version.dart
			version_check.dart
		targets/
			platform_ops.dart
			windows_platform_ops.dart
			linux_platform_ops.dart
		modules/
			global/
				global_builder.dart
				commands/
					tui.dart
					create.dart
					doctor.dart
					uninstall.dart
					upgrade.dart
					version.dart
	assets/
		templates/
			project-base/
				docs/
					adr/
						0001-record-architecture-decisions.md
					architecture.md
					roadmap.md
```

---

## 4. Especificacion de comandos

### 4.1 macss

Comando raiz sin subcomando.

Comportamiento:
- Muestra banner/TUI informativa no interactiva.
- Muestra version actual.
- Muestra comandos disponibles en v0.0.1.
- Muestra alias corto ma.
- Sugiere quickstart con macss create mi-proyecto.

Salida y codigo:
- exitCode = 0 si ejecuta correctamente.

### 4.2 macss create <path>

Scaffolding del proyecto base MACSS.

Entrada:
- parametro requerido path
- acepta cualquier ruta valida (relativa o absoluta)

Resolucion de ruta:
- si path es relativa, resolver contra directorio actual
- si path es absoluta, usar directamente

Comportamiento:
- Si el directorio destino no existe, crearlo.
- Trabajar dentro del directorio destino como raiz del proyecto generado.
- Crear directorios:
	- code/db
	- code/api
	- code/ui
- Crear archivos:
	- docs/adr/0001-record-architecture-decisions.md
	- docs/architecture.md
	- docs/roadmap.md
- El contenido inicial de esos archivos se toma desde assets/templates/project-base.
- No sobrescribir archivos existentes.
- Reportar acciones por item: created o exists.
- Si no hubo cambios, reportar estado idempotente.
- No usar flag force en v0.0.1.

Salida y codigo:
- exitCode = 0 en ejecucion valida.

### 4.3 macss doctor

Verifica el estado basico de instalacion local, similar a Inquiry.

Checks minimos obligatorios:
1. Version del binario macss disponible.
2. Existencia de carpeta de assets instalada.
3. Existencia de templates obligatorios:
	 - assets/templates/project-base/docs/adr/0001-record-architecture-decisions.md
	 - assets/templates/project-base/docs/architecture.md
	 - assets/templates/project-base/docs/roadmap.md

Salida y codigo:
- salida resumida por check (ok/error y remediation breve)
- exitCode = 0 si todos los checks pasan
- exitCode = 1 si uno o mas checks fallan

### 4.4 macss version

Imprime la version actual del CLI.

Comportamiento:
- Leer de fuente unica en lib/src/version.dart.
- Formato semver major.minor.patch.

Salida y codigo:
- texto plano: x.y.z
- exitCode = 0

### 4.5 macss uninstall

Desinstala el CLI del sistema local.

Comportamiento minimo:
1. Eliminar la carpeta de instalacion de macss de forma segura.
2. Quitar el directorio bin del PATH de usuario.
3. Eliminar o desregistrar el alias ma.
4. Mantener el comportamiento cross-platform igual al criterio de Inquiry.

Reglas de v0.0.1:
- En Windows debe tolerar lock del binario actual usando borrado diferido o estrategia equivalente.
- Debe dejar el sistema en un estado consistente aunque no existan archivos previos.
- Debe ser seguro ejecutar uninstall cuando la instalacion ya no existe.

Salida y codigo:
- salida textual confirmando desinstalacion o limpieza idempotente
- exitCode = 0 si termina correctamente

### 4.6 macss upgrade

Actualiza el CLI a la ultima version estable publicada en GitHub Releases.

Repositorio oficial para upgrades:
- ccisnedev/macss

Comportamiento minimo:
1. Consultar https://api.github.com/repos/ccisnedev/macss/releases/latest.
2. Parsear tag_name y comparar semver con version local.
3. Si no hay version mas nueva, informar already latest.
4. Seleccionar asset por plataforma:
	 - Windows x64: macss-windows-x64.zip
	 - Linux x64: macss-linux-x64.tar.gz
5. Descargar asset temporal.
6. Aplicar actualizacion sobre directorio de instalacion.
7. Ejecutar verificacion post-install con macss version.

Reglas de v0.0.1:
- solo releases estables (sin prerelease)
- soporte de arquitectura igual que Inquiry: Windows x64 y Linux x64

Requisitos de robustez:
- manejo de locks de binario en Windows (estrategia .bak)
- no corromper instalacion si falla descarga o extraccion
- limpiar temporales en exito y error

Salida y codigo:
- exitCode = 0 si termina correctamente (con o sin update)

---

## 5. Binario, alias e instalacion

Nombre del binario:
- Windows: macss.exe
- Linux: macss

Alias:
- ma (modular architecture)

Rutas de instalacion por defecto (igual que Inquiry):
- Windows: %LOCALAPPDATA%/macss
- Linux: ~/.macss

Integracion PATH/alias:
- Windows: agregar %LOCALAPPDATA%/macss/bin al PATH de usuario y crear ma.cmd
- Linux: crear symlink en ~/.local/bin/macss y ~/.local/bin/ma

Scripts esperados:
- code/cli/scripts/install.ps1 (Windows)
- code/site/install.sh (Linux, servida desde sitio web)
- code/cli/scripts/build.ps1 (compilacion local Windows)
- code/cli/scripts/build.sh (compilacion local Linux)
- code/cli/scripts/dev-install.ps1 (instalar desde fuente local Windows)
- code/cli/scripts/dev-install.sh (instalar desde fuente local Linux)

Soporte de desinstalacion:
- el comando macss uninstall es el mecanismo oficial de desinstalacion

Comportamiento minimo de instaladores:
- descargar latest release
- instalar binario y carpeta assets
- exponer comando macss y alias ma
- verificar con macss version

---

## 6. Versionado y sincronizacion

Fuente unica de version:
- code/cli/lib/src/version.dart

Sincronizacion obligatoria:
- code/cli/pubspec.yaml y code/cli/lib/src/version.dart deben coincidir

Pruebas minimas:
- test de version (retorna version actual)
- test de formato semver
- test de sync pubspec.yaml vs version.dart
- test de uninstall para limpieza de PATH y borrado diferido

Changelog:
- seguir criterio actual de Inquiry (manual, basado en semver)

---

## 7. CI minimo (similar a Inquiry)

Archivo esperado:
- .github/workflows/ci.yml

Comportamiento:
- trigger en push y pull_request cuando cambie code/cli/** o workflow
- matrix: ubuntu-latest y windows-latest
- en cada job:
	1. checkout
	2. setup-dart
	3. dart pub get
	4. dart analyze
	5. dart test

---

## 8. Release y deploy minimo (igual criterio de Inquiry)

Archivo esperado:
- .github/workflows/release.yml

Patron de 3 jobs:
1. check-version
	 - leer version de code/cli/pubspec.yaml
	 - verificar si tag vX.Y.Z ya existe
2. create-release
	 - crear tag
	 - crear GitHub Release
3. build
	 - matrix Windows/Linux
	 - compilar binario
	 - empaquetar binario + assets
	 - subir assets al release

Politica de release (igual Inquiry):
- release solo cuando la version no existe como tag remoto

Nombre de assets en release:
- macss-windows-x64.zip
- macss-linux-x64.tar.gz

---

## 9. Exit codes de v0.0.1

- 0: ejecucion correcta
- 1: error general no recuperable o doctor con checks fallidos
- 2: uso invalido (argumentos invalidos)
- 4: recurso no encontrado (asset/tag esperado no existe)
- 7: validacion fallida

---

## 10. Criterios de aceptacion de v0.0.1

1. macss imprime banner/TUI con comandos, version y alias ma.
2. macss create <path> crea scaffold dentro de la ruta destino.
3. macss create <path> es idempotente y no sobrescribe contenido.
4. macss create <path> usa templates desde assets/templates/project-base.
5. macss doctor valida presencia de assets/templates instalados.
6. macss uninstall limpia instalacion y PATH de forma segura e idempotente.
7. macss version imprime version semver valida.
8. macss upgrade consulta GitHub Releases (ccisnedev/macss) y aplica update por plataforma.
9. instaladores exponen macss y ma y verifican version.
10. CI corre en Windows y Linux con analyze + test.
11. release genera y publica los 2 assets esperados.

---

## 11. Fuera de alcance y siguiente version

Queda para v0.0.2:
- prompts interactivos de stack (--db, --api, --ui)
- generadores tecnologicos por stack (TS/Dart/Python/Flutter)

