# Extensibilidad y nuevos SDKs

MACSS esta disenado para crecer a nuevos lenguajes manteniendo el mismo contrato arquitectonico.

## Objetivo

Agregar SDKs nuevos (Go, Java, .NET) sin fragmentar el modelo.

## Requisitos minimos de un nuevo SDK

1. Soporte de UseCase + DTOs.
2. Mecanismo de rutas para comandos.
3. Integracion de queries por GraphQL cuando aplique.
4. Soporte de plugins base (health, metrics, logger).
5. Suite de pruebas equivalente.

## Matriz de paridad

Un SDK se considera alineado cuando demuestra paridad en:

1. capacidades funcionales,
2. contratos y validacion,
3. observabilidad minima,
4. pipeline de release.

## Camino recomendado

1. arrancar con core + comandos,
2. integrar plugins base,
3. agregar GraphQL,
4. completar quality gates,
5. publicar en release train.
