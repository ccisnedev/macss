# Plugins y capacidades transversales

En MACSS, las capacidades transversales se integran como plugins para evitar contaminar modulos de negocio.

## Plugins base recomendados

1. Health plugin: liveness/readiness.
2. Metrics plugin: metricas operativas.
3. Logger plugin: logs estructurados.
4. Middlewares de seguridad y errores.

## Regla de arquitectura

Un plugin transversal debe:

1. ser reusable,
2. no introducir acoplamiento de dominio,
3. operar por configuracion y contratos claros,
4. tener pruebas propias.

## Patrón de integracion

1. Se registra plugin en bootstrap de API.
2. Se expone configuracion declarativa.
3. Se documenta impacto en observabilidad y rendimiento.

## Crear un plugin propio

Checklist minimo:

1. objetivo tecnico unico,
2. API de configuracion estable,
3. compatibilidad con quality gates,
4. documentacion de uso y limites.
