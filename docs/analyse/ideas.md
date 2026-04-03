## 1) Objetivo y alcance

### Objetivo

Maximizar **velocidad** y **confiabilidad** del desarrollo usando agentes de AI como motor ejecutivo, manteniendo control humano sobre:

- arquitectura,
- contratos,
- criterios de aceptación,
- definición de “correcto” (tests),
- riesgos (seguridad, operabilidad, costos).

### Alcance

- Agnóstico de lenguaje/framework.
- Compatible con arquitecturas por capas, Clean/Hexagonal, microservicios o monolitos modulares.
- Se apoya en CI/CD, control de cambios y automatización de calidad.

### No objetivos

- Reemplazar criterio técnico humano en diseño.
- “Prompting” como mecanismo principal de calidad (MACSS exige verificación ejecutable).

---

## 2) Principios MACSS

1. **Especificación ejecutable primero**
    
    Todo requerimiento relevante se “compila” a tests/contratos/gates antes de implementar.
    
2. **Lazo cerrado obligatorio**
    
    La AI no “entrega”; la AI **itera** hasta que los gates pasen.
    
3. **Modularidad con fronteras fuertes**
    
    Módulos con dependencias explícitas y contratos versionados (API/DB/eventos).
    
4. **Sensores múltiples, no solo tests**
    
    Correctitud = tests + lint/format + tipos/validaciones + seguridad + performance básica + operabilidad mínima.
    
5. **Anti-trampa por diseño**
    
    La AI no debe poder “ganar” manipulando el sensor (tests/contratos/gates).
    

---

## 3) Modelo de agentes MACSS

MACSS define exactamente **dos agentes**: **Humano** y **AI**.

No son “personas”, son **roles operativos** con permisos, responsabilidades y entregables.

---

# A) Agente Humano (Orchestrator)

### Rol

**Orquestador y autoridad de especificación.**

Define *qué construir* y *cómo validar que está bien construido*.

### Responsabilidades (no delegables)

1. **Arquitectura y fronteras**
- Definir módulos/capas, dependencias permitidas, ownership, y políticas.
- Definir transacciones, consistencia, tolerancia a fallos, idempotencia, etc.
1. **Compilación de requerimientos a especificación**
- Convertir requerimientos en:
    - criterios de aceptación,
    - tests (unit/contract/integration/e2e),
    - contratos (API/DB/eventos),
    - “Definition of Done” (DoD) con gates.
1. **Validación de la calidad de los tests**
- Confirmar que los tests:
    - verifican comportamiento (no implementación),
    - cubren casos borde y negativos,
    - no son triviales,
    - no son frágiles/flaky,
    - representan fielmente el requerimiento.
1. **Gestión de riesgo**
- Seguridad, privacidad, cumplimiento, costos, SLO/SLI, observabilidad.
- Decidir trade-offs con trazabilidad (ADRs).
1. **Aprobación final**
- Aprueba cambios de contratos, cambios en tests de aceptación, cambios de arquitectura y release.

### Entregables típicos

- ADRs (decisiones arquitectónicas).
- Contratos (OpenAPI/AsyncAPI/Protobuf/DB contracts) y versionado.
- Matriz Requerimiento ↔ Test ↔ Gate.
- DoD por feature.
- Política anti-trampa y de calidad.

---

# B) Agente AI (Execution Engine)

### Rol

**Motor ejecutivo de implementación y convergencia.**

Optimiza el sistema hacia el cumplimiento de la especificación ejecutable.

### Responsabilidades (delegables, iterativas)

1. **Implementación**
- Generar/modificar código de módulos respetando fronteras.
- Mantener consistencia con contratos, estilos, convenciones.
1. **Ejecución de lazo cerrado**
- Ejecutar gates (tests + checks).
- Interpretar fallos (logs/stack traces/diffs).
- Proponer parches incrementales hasta pasar DoD.
1. **Refactor controlado**
- Refactorizar preservando comportamiento (tests como red).
- Reducir complejidad y duplicación manteniendo gates verdes.
1. **Producción de artefactos auxiliares**
- Documentación técnica de módulos.
- Scripts de verificación y reproducibilidad.
- Generación de stubs/mocks/fakes donde aplique.

### Restricciones / límites (recomendados)

- No modificar **tests de aceptación/contratos** sin autorización explícita del Humano.
- No reducir cobertura mínima ni desactivar gates.
- No introducir `skip/xfail` (o equivalentes) salvo política explícita.
- No cambiar interfaces públicas sin actualizar contrato + pruebas de compatibilidad.

### Entregables típicos

- Diffs/PRs implementando features o fixes.
- Reportes de ejecución de gates (qué falló, por qué, cómo se corrigió).
- Propuestas de refactor con evidencia (tests verdes).

---

## 4) Matriz RACI simplificada (Humano vs AI)

| Actividad | Humano | AI |
| --- | --- | --- |
| Definir arquitectura y límites | **A/R** | C |
| Definir contratos (API/DB/eventos) | **A/R** | C |
| Convertir requerimiento a tests (aceptación/contrato) | **A/R** | C (puede proponer) |
| Implementar código | C | **A/R** |
| Ejecutar y depurar gates | C | **A/R** |
| Refactor | A (aprueba) | R |
| Cambiar tests de aceptación/contratos | **A/R** | C (proponer) |
| Release | **A/R** | C |

A = Accountable, R = Responsible, C = Consulted

---

## 5) Ciclo MACSS (flujo operativo estándar)

### Fase 0 — Preparación (una vez por repositorio/producto)

1. Definir módulos/capas y reglas de dependencia.
2. Definir gates y comandos estándar:
    - `lint`, `format`, `typecheck` (si aplica), `test:unit`, `test:contract`, `test:integration`, `test:e2e`, `security`, `perf:smoke`
3. Definir políticas anti-trampa + ownership de directorios.
4. Definir scaffolding de pruebas deterministas y entornos reproducibles.

### Fase 1 — Spec (Humano)

Entrada: requerimiento.

Salida: especificación ejecutable.

Checklist Spec:

- criterios de aceptación (Given/When/Then),
- tests de aceptación (mínimos, alto valor),
- contratos actualizados (si cambia API/DB/eventos),
- casos negativos/borde,
- DoD con gates y umbrales.

### Fase 2 — Implement (AI)

Entrada: spec + restricciones.

Salida: implementación candidata.

Loop AI:

1. implementar cambios mínimos,
2. correr gates,
3. capturar fallos,
4. aplicar patch,
5. repetir hasta DoD.

### Fase 3 — Review/Freeze (Humano)

- Validar que los tests realmente representan el requerimiento.
- Validar riesgos: seguridad, performance, operabilidad, mantenibilidad.
- Aceptar/iterar.

### Fase 4 — Release (Humano + automatización)

- Ejecutar pipeline completo.
- Publicar artefactos.
- Monitoreo post-release.

---

## 6) Estructura de “especificación ejecutable” (agnóstica de stack)

MACSS recomienda separar suites por intención, no por tecnología:

- **Unit**: lógica pura (rápido, determinista).
- **Contract**: compatibilidad entre módulos/servicios (API/eventos/DB contracts).
- **Integration**: IO real controlado (DB/colas/FS/externos con stub).
- **E2E**: flujos críticos mínimos (pocos, estables).

Regla MACSS:

- “Unit” **no** toca red/DB/proceso externo.
- Si toca infraestructura real: es **integration**.

---

## 7) Políticas anti-trampa (mínimo viable)

1. **Congelación de spec**
- Una vez definidos tests de aceptación/contratos para un requerimiento, se bloquean durante la implementación (salvo excepción aprobada).
1. **Ownership de carpetas**
- AI-Implement no puede editar:
    - `tests/acceptance/*`
    - `contracts/*`
    - `docs/adr/*`
        
        sin permiso explícito.
        
1. **Gates obligatorios**
- Prohibido:
    - bajar umbrales,
    - deshabilitar jobs,
    - introducir skips.
1. **Determinismo**
- Flaky tests se tratan como bug severo de la metodología (rompe el lazo cerrado).

---

## 8) Plantilla MACSS para especificar un requerimiento

**Req-ID:** MACSS-REQ-###

**Descripción:** …

**Impacto en módulos:** …

**Contrato afectado:** sí/no (detallar)

### Aceptación (Given/When/Then)

- G1: …
- G2: …

### Invariantes

- I1: …
- I2: …

### Casos borde / negativos

- N1: …
- N2: …

### Gates y umbrales

- `test:unit` debe pasar
- `test:contract` debe pasar
- `test:integration` debe pasar
- `security` sin findings críticos
- `perf:smoke` dentro de presupuesto (si aplica)

### Matriz Requerimiento ↔ Tests

| Criterio | Tipo test | Nombre test | Gate |
| --- | --- | --- | --- |
| G1 | acceptance | … | test:e2e |
| I1 | unit/property | … | test:unit |
| Contrato API | contract | … | test:contract |

---

## 9) “Protocol” de trabajo (para que la AI opere sin ambigüedad)

### Input mínimo que el Humano entrega a la AI

- Alcance exacto (qué sí / qué no).
- DoD y gates que deben pasar.
- Restricciones:
    - módulos permitidos,
    - archivos prohibidos,
    - contratos que no se pueden romper,
    - estándares (naming, error model).
- Evidencia deseada:
    - comandos ejecutados,
    - resultados de tests,
    - diff incremental.

### Output mínimo que la AI devuelve

- Plan corto (pasos ejecutables).
- Cambios (diff/PR).
- Resultado de gates (qué pasó/qué falló y cómo se corrigió).
- Notas de riesgo (si detecta).

---

## Próximo paso de documentación (orden recomendado)

1. **Definición formal de MACSS** (1–2 páginas): principios + agentes + ciclo.
2. **Guía de estructura de repositorio** (agnóstica): carpetas, ownership, gates.
3. **Guía de tests**: taxonomía, anti-flakiness, contratos, datos de prueba.
4. **Playbooks**: feature, bugfix, refactor, cambio de contrato, cambio de DB.
5. **Métricas MACSS**: tiempo a verde, tasa de flakiness, defect escape rate, etc.

Si quieres, en el siguiente mensaje puedo entregarte el documento en formato **Markdown listo para repositorio** (README + secciones) con numeración estable y plantillas (ADR, contrato, requerimiento, PR checklist) alineadas a MACSS.

[modular_api](https://www.notion.so/modular_api-30f7ba52ced981a1a8fef5c9f1bbe137?pvs=21)

[Capas](https://www.notion.so/Capas-30f7ba52ced98037b733d3426d6bab9c?pvs=21)

[Glosario](https://www.notion.so/Glosario-30f7ba52ced980be9d81e2c342dff353?pvs=21)

[Testing](https://www.notion.so/Testing-30f7ba52ced980d2897cc18faa4c6447?pvs=21)

[Flow](https://www.notion.so/Flow-30f7ba52ced9808c87bcc8884942de6a?pvs=21)

[Estructura](https://www.notion.so/Estructura-30f7ba52ced980a28a8bea30b2c6639d?pvs=21)