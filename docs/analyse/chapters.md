# Estructura final del libro MACSS

> Objetivo del libro:
> 1) documentacion viva de arquitectura,
> 2) guia de adopcion e ingenieria,
> 3) base de expansion para nuevos SDKs.

---

## 1. Criterios rectores

1. Prioridad tecnica: arquitectura y ejecucion de ingenieria.
2. Introduccion completa para quien solo quiere usar paquetes.
3. Profundizacion separada para quien quiere adoptar, extender y contribuir.
4. Operacion avanzada separada para equipos en produccion.
5. Glosario como contrato semantico del sistema.

---

## 2. Estructura editorial canonica

## Parte I - Mapa y uso inmediato

### Capitulo 1. Introduccion y mapa MACSS
- Que es arquitectura y que es arquitectura de software.
- Problema que resuelve MACSS.
- Vista completa del sistema y rutas de lectura por perfil.

### Capitulo 2. Arquitectura canonica en diagrama
- Diagrama de capas: interface, server, db e infraestructura.
- Flujo canonico request -> use case -> db -> response.

### Capitulo 3. Mapa de paquetes y complementos
- Core de APIs modulares por caso de uso.
- Plugins base: health, metrics, logger.
- Plugin GraphQL para completar CQRS.
- CLI y modulo DevOps (PowerShell) como herramientas complementarias.

### Capitulo 4. Quickstart de consumo
- Como usar paquetes sin entrar en detalle interno.
- Ejemplo minimo extremo a extremo.

---

## Parte II - Arquitectura MACSS en profundidad

### Capitulo 5. Principios nucleares y trade-offs
- Reglas no negociables.
- Limites y concesiones conscientes.

### Capitulo 6. Modelo modular por caso de uso
- UseCase como unidad atomica.
- DTOs y contratos explicitos.
- Fronteras de modulo.

### Capitulo 7. Estructura canonica de proyecto
- Estructura de carpetas por capas y modulos.
- Integracion entre app, api, db y servicios externos.

### Capitulo 8. Plugins y capacidades transversales
- Health, metrics, logger y middlewares.
- Criterios para desarrollar plugins propios.

### Capitulo 9. CQRS y GraphQL
- Commands por REST y queries por GraphQL.
- Reglas de separacion y compatibilidad.

### Capitulo 10. Integraciones y limites operativos
- Database as Code.
- Integraciones externas, resiliencia y asincronia.

### Capitulo 11. Glosario MACSS
- Definiciones cortas, no solapadas y operativas.
- Termino -> evidencia tecnica.

### Capitulo 12. Extensibilidad y nuevos SDKs
- Como crear SDKs nuevos (Go, Java, .NET).
- Matriz de paridad y conformidad.

---

## Parte III - Ingenieria y operacion avanzada

### Capitulo 13. Flujo de desarrollo estandar
- Ciclo diario de trabajo en MACSS.
- Integracion de herramientas y equipos.

### Capitulo 14. Testing y quality gates
- Especificacion ejecutable.
- Gates minimos por PR y release.

### Capitulo 15. CI/CD y release train
- Flujo de build, test, publish y rollback.
- Sincronizacion multi-SDK.

### Capitulo 16. Observabilidad y operacion real
- Logs, metricas, salud y trazabilidad.
- Criterios de operacion en produccion.

### Capitulo 17. Modelo Humano + AI
- Responsabilidades, guardrails y lazo cerrado.
- Politicas anti-trampa y evidencia de calidad.

### Capitulo 18. Gobernanza y ADR
- Como se toman decisiones de arquitectura.
- Politica de cambios y deprecaciones.

---

## 3. Apendices

1. Source map y trazabilidad editorial.
2. Plantillas y checklists operativos.
3. Nota minima de identidad (una linea, no capitulo).

---

## 4. Definicion de listo por capitulo

Cada capitulo debe incluir:

1. Definicion conceptual.
2. Reglas operativas.
3. Ejemplo concreto.
4. Anti-patrones o errores frecuentes.
5. Evidencia verificable (tests, contratos, ADR, pipelines o checklist).

---

## 5. Decision

Se adopta una estructura final de 3 partes + apendices.

Razon:

1. Maximiza utilidad para lectores tecnicos que solo consumen paquetes.
2. Separa onboarding, profundidad arquitectonica y operacion avanzada.
3. Mantiene al libro como documento vivo, escalable a nuevos SDKs.
