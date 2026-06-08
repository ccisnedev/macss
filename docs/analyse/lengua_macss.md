# Lengua MACSS

> Vocabulario operativo para traducir conceptos de Le Corbusier y apicultura al diseno de arquitectura de software en MACSS.

---

## 1. Proposito

Este documento define una lengua comun para:

1. Nombrar decisiones arquitectonicas sin ambiguedad.
2. Conectar teoria (Le Corbusier y apicultura) con practica de software.
3. Evitar discusiones semanticas esteriles en revisiones tecnicas.

Regla de uso:

- Un termino de esta lengua debe poder convertirse en una accion verificable (contrato, test, regla de dependencia, gate o ADR).

---

## 2. Raiz conceptual A: Le Corbusier -> MACSS

### 2.1 Diccionario base

| Concepto original | Sentido arquitectonico | Traduccion en lengua MACSS |
|---|---|---|
| Dom-Ino | Estructura portante modular independiente del cerramiento | Esqueleto estable del sistema (fronteras de modulo + contratos + dependencias permitidas) |
| Modulor | Sistema proporcional para dimensionar con coherencia | Sistema de proporciones de decisiones (reglas de naming, tamano de modulo, granularidad de casos de uso, niveles de prueba) |
| Plan libre | Distribucion interna no atada a muros portantes | Libertad de implementacion dentro del modulo sin romper contrato externo |
| Facade libre | Envolvente independiente de estructura | API/Schema independiente de detalles internos |
| Pilotis | Soporte estructural que libera el espacio | Infraestructura base que habilita evolucion del dominio |
| Maison machine-a-habiter | Diseno para uso real, no para ornamento | Arquitectura al servicio del flujo operativo y mantenimiento |
| Promenade architecturale | Experiencia de recorrido coherente | Flujo request->use case->data->response legible de extremo a extremo |

### 2.2 Axiomas MACSS derivados

1. Estructura fuerte, implementacion flexible.
2. Contrato estable, interior evolutivo.
3. Proporciones comunes, soluciones diversas.
4. Legibilidad primero, optimizacion despues.

---

## 3. Raiz conceptual B: Apicultura -> MACSS

### 3.1 Diccionario base

| Concepto original | Sentido en apicultura | Traduccion en lengua MACSS |
|---|---|---|
| Foundation (cera estampada) | Guia inicial para construir panal con menos friccion | Plantilla canonica (estructura de modulo, convenciones y ejemplos) |
| Marco movil (hive frame) | Unidad manipulable e inspeccionable sin destruir colmena | Modulo inspeccionable y testeable de forma aislada |
| Panal hexagonal | Eficiencia estructural con variacion local | Estandar comun de composicion con adaptacion por dominio |
| Bee space | Separacion precisa que evita bloqueos por cera/propolis | Distancia de acoplamiento controlada entre modulos |
| Extraccion sin destruir panal | Reutilizar estructura y preservar continuidad | Refactor seguro con contratos y tests verdes |
| Colmena saludable | Homeostasis y funcionamiento sostenido | Sistema operable: observabilidad, confiabilidad y mantenimiento continuo |

### 3.2 Axiomas MACSS derivados

1. Plantilla primero, variacion despues.
2. Acoplamiento calibrado evita bloqueos evolutivos.
3. La estructura se preserva para acelerar iteracion.
4. Salud del sistema importa mas que velocidad puntual.

---

## 4. Glosario operativo MACSS

### 4.1 Terminos nucleares

| Termino MACSS | Definicion corta | Evidencia esperada |
|---|---|---|
| Esqueleto | Conjunto minimo no negociable de estructura y contratos | Mapa de modulos, reglas de dependencia, contrato versionado |
| Proporcion | Regla de escala para no sobredisenar ni subdisenar | Limites de tamano de modulo, complejidad y alcance por caso de uso |
| Modulo habitable | Modulo entendible, testeable y operable por cualquier integrante del equipo | README de modulo, tests utiles, metricas basicas, runbook |
| Frontera fuerte | Limite explicito entre responsabilidad interna y contrato externo | Tipos/DTO publicos, OpenAPI/GraphQL, test de contrato |
| Lazo cerrado | Ciclo obligatorio de implementar->verificar->corregir | Pipeline con gates obligatorios y feedback corto |
| Sensor | Mecanismo objetivo de deteccion de desvio | Test, lint, typecheck, seguridad, performance smoke |
| Trampa de sensor | Cambio que hace pasar un gate sin resolver el problema real | Cambios sospechosos en tests de aceptacion/umbrales/gates |

---

## 5. Gramatica de decisiones (plantillas de frase)

Usa estas formulas para redactar ADRs, PRs o discusiones tecnicas.

### 5.1 Patron de estructura

- "Conservamos el esqueleto [X], flexibilizamos la implementacion [Y], y validamos con sensor [Z]."

### 5.2 Patron de proporcion

- "Este cambio respeta la proporcion MACSS porque reduce acoplamiento [A] sin romper frontera [B]."

### 5.3 Patron de anti-trampa

- "El gate esta verde, pero no hay evidencia de comportamiento [X]; falta sensor [Y]."

### 5.4 Patron de evolucion segura

- "Refactorizamos interior de modulo sin cambiar contrato; prueba de compatibilidad: [enlace/test]."

---

## 6. Anti-patrones de lenguaje (lo que MACSS evita)

| Anti-patron | Senal linguistica | Riesgo |
|---|---|---|
| Arquitectura ornamental | "se ve moderno" sin criterio verificable | Complejidad sin valor |
| Contrato cosmetico | "el endpoint existe" pero sin semantica estable | Integraciones fragiles |
| Modulo cajon desastre | "todo entra aqui" | Acoplamiento caotico |
| Test placebo | "pasa CI" sin cubrir comportamiento real | Falsa sensacion de calidad |
| Prompt-centrismo | "la IA lo resuelve" sin estructura | Deriva e inconsistencia |

---

## 7. Correspondencia rapida para equipos

### Si dices "Dom-Ino" en MACSS, significa:

1. Definir esqueleto primero.
2. Separar estructura de implementacion.
3. Permitir combinacion modular sin rehacer la base.

### Si dices "Modulor" en MACSS, significa:

1. Definir proporciones de diseno antes de escalar.
2. Repetir patrones de buena forma en todos los modulos.
3. Estandarizar la gramatica, no clonar soluciones.

### Si dices "Foundation" en MACSS, significa:

1. Dar una guia inicial de alta calidad.
2. Facilitar que humanos e IA construyan sobre un patron comun.
3. Mantener variacion contextual dentro de limites seguros.

---

## 8. Criterio de aceptacion de esta lengua

La lengua MACSS esta bien aplicada cuando:

1. Cada termino usado en una decision tecnica apunta a evidencia verificable.
2. Dos equipos distintos interpretan igual la misma directriz.
3. Un cambio se puede evaluar por estructura, contrato y sensores.
4. La IA produce resultados mas consistentes al recibir este vocabulario como contexto.

---

## 9. Formula canonica

MACSS = Esqueleto (Dom-Ino) + Proporcion (Modulor) + Guia generativa (Foundation) + Verificacion continua (Sensores)

Interpretacion:

- Esqueleto sin proporcion produce rigidez.
- Proporcion sin esqueleto produce discurso sin estructura.
- Guia sin sensores produce ilusiones de avance.
- Sensores sin lengua comun producen ruido operativo.

---

## 10. Uso recomendado en el repo

1. Referenciar este documento en ADRs de arquitectura.
2. Reutilizar sus terminos en plantillas de PR.
3. Incluir sus axiomas en prompts de agentes AI.
4. Mantener el glosario versionado junto al sistema.

