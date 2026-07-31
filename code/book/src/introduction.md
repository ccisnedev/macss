# Introduccion y mapa MACSS

MACSS es una arquitectura para construir APIs modulares por caso de uso con contratos explicitos y validacion ejecutable.

Esta introduccion busca que un lector entienda todo el mapa del sistema en una sola lectura:

1. Que es arquitectura y que es arquitectura de software en este contexto.
2. Cual es el core tecnico de MACSS.
3. Que paquetes y complementos existen.
4. Como recorrer el libro segun su objetivo.

## Arquitectura y arquitectura de software

En MACSS, arquitectura es la disciplina de separar responsabilidades, definir contratos y fijar restricciones para que el sistema sea evolutivo.

Arquitectura de software significa:

1. estructura de componentes,
2. relaciones entre capas y modulos,
3. reglas de evolucion y validacion.

## El core de MACSS

El core no es un framework monolitico: es una gramatica arquitectonica.

Sus pilares son:

1. API modular por caso de uso.
2. DTOs de entrada y salida definidos por contrato.
3. Separacion de comandos y consultas (CQRS).
4. Database as Code para persistencia declarativa.
5. Testing y quality gates como especificacion ejecutable.

## Mapa de capas

La arquitectura canonica se organiza en capas visibles y simetricas:

1. Interface (app/cli).
2. Server API (transport + use cases + repositories).
3. DB (esquema y datos declarativos).
4. Infra (entorno, CI/CD y automatizacion).

La logica de negocio vive en UseCases; las capas de interfaz y transporte no la duplican.

## Mapa de paquetes y complementos

Para adopcion practica, el ecosistema se divide en:

1. Core modular API.
2. Plugins transversales: health, metrics, logger.
3. Plugin GraphQL para consultas y cierre del modelo CQRS.
4. CLI companion para operaciones de desarrollo.
5. Modulo DevOps en PowerShell para automatizacion operativa.

## Rutas de lectura

Si quieres solo usar paquetes:

1. Lee esta introduccion completa.
2. Lee arquitectura canonica en diagrama.
3. Lee mapa de paquetes y quickstart.

Si quieres adoptar o contribuir a MACSS:

1. Recorre toda la Parte II.
2. Profundiza en glosario, limites e integraciones.
3. Revisa extensibilidad para plugins y SDKs.

Si quieres operar en produccion:

1. Recorre toda la Parte III.
2. Enfocate en quality gates, CI/CD, observabilidad y gobernanza.
