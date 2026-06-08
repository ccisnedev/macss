# Quickstart de consumo

Este capitulo es para quien quiere usar paquetes MACSS con el minimo contexto.

## Paso 1: elegir SDK

1. Dart.
2. TypeScript.
3. Python.

La estructura conceptual es la misma en todos los SDKs.

## Paso 2: crear un modulo minimo

Un modulo minimo define:

1. Input DTO.
2. Output DTO.
3. UseCase con `execute()`.
4. Ruta de API.

## Paso 3: conectar plugins base

Activa como minimo:

1. health,
2. metrics,
3. logger.

Si necesitas consultas flexibles, agrega GraphQL plugin.

## Paso 4: validar con gates minimos

1. lint/format,
2. unit tests,
3. contract tests,
4. integration test de ruta principal.

## Resultado esperado

Al finalizar este quickstart debes poder:

1. exponer una API modular funcional,
2. observar estado y metricas,
3. ejecutar pipeline base sin errores.

La Parte II explica por que esta composicion funciona y como extenderla.
