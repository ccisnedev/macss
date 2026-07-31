# Mapa de paquetes y complementos

MACSS se consume como ecosistema de paquetes y herramientas complementarias.

## Paquetes nucleares

1. `modular_api`: core de APIs modulares por caso de uso.
2. SDKs oficiales actuales: Dart, TypeScript y Python.

## Plugins esenciales

1. Health: expone estado operativo y readiness.
2. Metrics: publica metricas tecnicas y de negocio.
3. Logger: logging estructurado para trazabilidad.
4. GraphQL: habilita consultas y completa CQRS sobre el core.

## Herramientas complementarias

1. `macss` CLI: companion para scaffolding y tareas de desarrollo.
2. `macss-devops` (PowerShell): companion operativo para CI/CD, release y automatizacion de entorno.

## Regla de composicion

Un proyecto MACSS integra piezas en este orden:

1. core modular,
2. plugins transversales,
3. plugin GraphQL (si aplica),
4. tooling companion.

Esto permite empezar simple y escalar sin cambiar el modelo arquitectonico.
