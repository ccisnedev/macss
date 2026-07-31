# Notas de revisión — modular_api 0.4.8

Fecha: 2026-06-09
Contexto: primera implementación real completa del ecosistema modular_api
Stack verificado: PostgreSQL + Dart (servidor) + Flutter web (cliente) + Playwright (QA)

---

El módulo es la unidad correcta de abstracción. Un archivo registra el endpoint, una clase es el use case, y el framework se encarga del resto (routing, JSON parsing, status codes, documentación OpenAPI). No hay boilerplate. Agregar un endpoint nuevo es agregar una clase.

La separación GraphQL/REST no es cosmética. Haberla implementado como dos clientes distintos en Flutter con responsabilidades claras — GraphQL para leer, REST para actuar — es CQRS real, no solo en el nombre. La mayoría de proyectos "CQRS" terminan mezclando todo.

El patrón de inyección de dependencias en los use cases es elegante. El mismo ValidarDni funciona en producción (con deps reales) y en tests (con deps inyectadas) sin ningún framework de DI ni magia. Es Dart puro.

buildSorteoCatalog() como fuente de verdad del schema GraphQL es una idea sólida. Un archivo describe las tablas, el framework genera el schema completo. Sin generación de código, sin sincronización manual.

deuda técnica real:
El catálogo GraphQL es manual y frágil. Si agregas una columna en PostgreSQL y olvidás actualizarlo, el schema GraphQL queda desincronizado. No hay validación en runtime que detecte eso. En producción eso es silencioso y peligroso. La solución correcta es generación desde el schema SQL o introspección — y está en el roadmap, pero todavía no existe.

El translator T-SQL → PostgreSQL es un riesgo acumulado. Funciona para los patrones actuales, pero cada vez que el framework genere un nuevo patrón T-SQL que el translator no cubra, va a fallar silenciosamente en PostgreSQL. Ese archivo va a crecer con casos especiales.

La URL hardcodeada en constants.dart es fricción operacional. Cambiar de desarrollo a producción requiere editar código. Debería ser una variable de entorno o build flavor.

## Estado de la implementación

La serie `0.4.x` cierra con una prueba de implementación end-to-end funcional:

- `modular_api_rest_client 0.4.8` — cliente HTTP multiplataforma (web, mobile, desktop, server)
- `modular_api_graphql_client 0.4.7` — cliente GraphQL sobre REST client
- Servidor Dart con rutas REST y endpoint GraphQL (`/api/v2/graphql`)
- UI Flutter web consumiendo ambas capas
- Suite Playwright de 41 tests cubriendo health, GraphQL, REST y flujos UI — 41/41 passing

El hito principal de `0.4.8` fue reemplazar `dart:io` `HttpClient` por `package:http`,
que resuelve la incompatibilidad silenciosa con Flutter web (dart2js). Desde esta versión
el stack está verificado en todas las plataformas que el ecosistema promete soportar.

---

## Evaluación arquitectónica del ecosistema

### Adopción progresiva REST → GraphQL

Calificación: **9/10**

La separación de paquetes (`rest_client` vs `graphql_client`) hace que la adopción sea
aditiva, no disruptiva. Un proyecto puede operar años en modo REST puro y agregar el
read side GraphQL cuando la complejidad de queries lo justifique. Esto es CQRS progresivo
real: el write side (comandos REST) y el read side (queries GraphQL) evolucionan
independientemente.

Trabajo pendiente: el mapping manual del catalog GraphQL (`sorteo_graphql_catalog.dart`)
es fricción. La generación de código desde el schema eliminaría esa barrera de adopción.

### Separación modular como ruta a microservicios

Calificación: **7/10**

La arquitectura habilita el split, no lo garantiza. Si el desarrollador construye con
bounded contexts claros, migrar a microservicios es cambiar una URL de endpoint. Si no,
la separación de paquetes no resuelve el acoplamiento lógico subyacente.

Lo que sí aporta el ecosistema: los contratos entre módulos están explícitos en los
paquetes pub.dev versionados. Eso es mejor punto de partida que imports directos entre
carpetas de un monolito sin fronteras.

### Monorepo + corte vertical para equipo pequeño

Calificación: **9/10**

Un solo desarrollador puede hacer un cambio que atraviesa DB → API → UI → test en un
solo commit, con visibilidad total de impacto. Sin coordinación cruzada entre repos,
sin esperar publicaciones de otros equipos, sin deploy hell de dependencias.

Para el target real de MACSS (equipos de 1-5 personas) esto es un multiplicador de
productividad concreto. La mayoría de proyectos en ese rango sufren exactamente el
overhead inverso: repos separados, coordinación artificial, deploys desincronizados.

### AI como amplificador con contexto total

Calificación: **10/10 — idea más original del ecosistema**

Esta propiedad no estaba en el diseño de ninguna arquitectura clásica porque el contexto
era irrelevante cuando el único consumidor era un desarrollador humano. Con un LLM como
herramienta de desarrollo activa, tener `infra/ db/ api/ app/ qa/` en un solo árbol con
convenciones de naming consistentes es una ventaja estructural real.

Durante la implementación de la serie `0.4.x` se verificó esto en práctica: fue posible
trazar `Playwright test → Flutter widget → modular_api_graphql_client →
modular_api_rest_client → server route → SQL function` sin salir del contexto de la
herramienta AI. El diagnóstico de un bug que cruzaba cinco capas tomó minutos en lugar
de horas.

Una arquitectura diseñada para ser consumida por AI además de por humanos tiene ventaja
sobre diseños que solo optimizan para el lector humano. Esta propiedad merece documentación
explícita como principio de MACSS, no solo como efecto secundario del monorepo.

---

## Nota: potencial artículo de presentación

El punto "AI como amplificador con contexto total" tiene potencial para un artículo de
presentación del ecosistema (LinkedIn, Medium, dev.to). El argumento central:

> Las arquitecturas clásicas optimizan para que el desarrollador humano navegue el
> código. Una arquitectura diseñada para el contexto de 2025 también optimiza para que
> un agente AI tenga el contexto completo para ejecutar cambios correctos en un corte
> vertical sin perder información entre capas.

El artículo podría apoyarse en la implementación real del stack
PostgreSQL + Dart + Flutter web como prueba de concepto ejecutable, con la suite
Playwright como evidencia de correctitud verificable.

---

## Trabajo técnico pendiente identificado

1. **CI con `flutter test --platform chrome`** antes de cada release de paquetes Dart.
   La compatibilidad web no es opcional para paquetes que prometen soporte multiplataforma.

2. **Generación de catalog GraphQL desde schema** — elimina el mapping manual y reduce
   la fricción de adopción del read side.

3. **Script de dev workflow para path overrides** — activar/desactivar
   `pubspec_overrides.yaml` de forma controlada para no arriesgar commits con referencias
   locales.

---

## Decisión pendiente: migración a 0.5.0

La serie `0.4.x` acumuló breaking changes continuos porque la implementación estaba
en construcción. Con la primera implementación real completa y verificada, tiene sentido
coordinar un bump a `0.5.0` en todos los paquetes del ecosistema:

- Señala que desde esta versión el semver se maneja con responsabilidad.
- Marca la línea entre "bootstrap experimental" y "plataforma con contratos estables".
- El `^0.4.x` de los consumidores existentes no resuelve `0.5.0` automáticamente,
  lo que fuerza una adopción consciente.

Paquetes a coordinar: `modular_api_rest_client`, `modular_api_graphql_client`, y
cualquier otro paquete core del ecosistema que esté en serie `0.4.x`.
