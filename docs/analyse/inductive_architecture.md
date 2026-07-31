MACSS — ESPECIFICACIÓN DE ARQUITECTURA INDUCTIVA
Versión 0.1

Nombre conceptual: Wax Foundation
Nombre de la práctica: Inductive Architecture Engineering
Arquitectura de referencia: MACSS — Modular Architecture for Comprehensive Software Solutions

1. PROPÓSITO

Esta especificación define una metodología para diseñar repositorios de software cuya arquitectura revele estructuralmente su propósito, sus reglas de composición y su forma correcta de extensión.

La metodología parte del siguiente principio:

La arquitectura no es solamente una estructura para ejecutar software; es un molde semántico que condiciona probabilísticamente el código que producirán sus futuros participantes.

El repositorio completo funciona como una fuente de contexto. Su arquitectura, nombres, distribución física, dependencias, ejemplos, contratos, documentación y mecanismos de validación deben comunicar de manera coherente cómo se construye el sistema.

El objetivo no es añadir más información al repositorio, sino aumentar su densidad de señal y reducir su ruido.

Una persona o agente que observe una muestra local suficiente del proyecto debe poder inferir:

* qué responsabilidad tiene cada componente;
* dónde debe implementarse una nueva funcionalidad;
* qué dependencias están permitidas;
* qué patrones deben reutilizarse;
* qué decisiones arquitectónicas deben preservarse;
* cómo se valida que una implementación es correcta;
* qué elementos deben modificarse conjuntamente;
* qué extensiones son compatibles con la arquitectura;
* qué acciones constituyen una desviación arquitectónica.

La metodología es agnóstica respecto de herramientas, editores, modelos, proveedores y plataformas de automatización.

2. TESIS CENTRAL

Your codebase is the prompt.

Esta afirmación se amplía de la siguiente manera:

El repositorio es un sistema de señales arquitectónicas.

El comportamiento futuro de quienes modifican un sistema está condicionado por los patrones que el repositorio hace visibles, accesibles, repetibles y verificables.

Por tanto, una arquitectura bien diseñada no debe limitarse a separar responsabilidades. También debe enseñar inductivamente cómo continuar el sistema.

La arquitectura debe ser simultáneamente:

* ejecutable;
* comprensible;
* observable;
* navegable;
* consistente;
* extensible;
* verificable;
* autoexplicativa;
* inductiva.

3. CONCEPTO: WAX FOUNDATION

3.1 Definición

Wax Foundation es el nombre conceptual del molde arquitectónico que guía la extensión de un repositorio.

En apicultura, una wax foundation es una lámina de cera estampada con el patrón base de las celdas del panal. No construye el panal completo, pero define la geometría inicial que orienta su crecimiento.

Aplicado a la arquitectura de software:

Wax Foundation es el conjunto mínimo de señales estructurales, semánticas y verificables que permite inferir cómo extender correctamente un sistema.

La Wax Foundation:

* no contiene todas las implementaciones posibles;
* no describe cada decisión local;
* no reemplaza el criterio de ingeniería;
* no prescribe línea por línea el código futuro;
* no llena todo el espacio disponible;
* marca la geometría necesaria;
* reduce la ambigüedad;
* favorece extensiones compatibles;
* hace visibles las decisiones globales;
* permite verificar desviaciones.

3.2 Traducción conceptual

En español puede utilizarse:

* Lámina de Cera Arquitectónica;
* Lámina Guía Arquitectónica;
* Fundación de Cera;
* Molde Arquitectónico Inductivo.

El término inglés recomendado es:

Architectural Wax Foundation

“Beeswax” no es suficientemente preciso porque se refiere al material, no a la lámina estampada utilizada como base del panal.

“Wax Foundation” es el término apícola más cercano al concepto buscado.

3.3 Nombre de la práctica

La metáfora no debe sustituir el nombre técnico de la disciplina.

El nombre recomendado para la práctica es:

Inductive Architecture Engineering

Traducción:

Ingeniería de Arquitectura Inductiva

Wax Foundation es el modelo conceptual.

Inductive Architecture Engineering es la práctica de ingeniería utilizada para diseñarlo, mantenerlo y evaluarlo.

4. DEFINICIÓN DE ARQUITECTURA INDUCTIVA

Una arquitectura inductiva es una arquitectura cuya estructura observable permite inferir de manera consistente cómo debe extenderse el sistema.

Formalmente:

Una arquitectura A es inductiva cuando una muestra local representativa de un repositorio construido bajo A contiene suficientes señales para producir extensiones compatibles con las decisiones globales de A.

La arquitectura inductiva busca que los patrones correctos sean:

* evidentes;
* cercanos;
* consistentes;
* repetibles;
* difíciles de interpretar incorrectamente;
* más fáciles de seguir que de evitar.

La inducción no depende de una instrucción aislada. Surge de la coherencia entre múltiples capas del repositorio.

Arquitectura inductiva =

Arquitectura

* estructura física
* código canónico
* convenciones
* contratos
* pruebas
* documentación jerárquica
* decisiones arquitectónicas
* restricciones ejecutables
* estándares de industria
* validaciones automatizadas

5. ALCANCE

Esta especificación se enfoca en la capa arquitectónica global de un proyecto.

Su objetivo es enseñar cómo utilizar y extender la arquitectura base.

No define:

* reglas específicas de negocio;
* comportamiento funcional de cada módulo;
* conocimiento completo del dominio;
* decisiones particulares de cada caso de uso;
* implementación detallada de funcionalidades;
* una metodología de levantamiento de requisitos;
* una estrategia de gestión del producto.

La Wax Foundation de MACSS debe permitir responder principalmente:

* cómo se crea un nuevo módulo;
* cómo se agrega una funcionalidad;
* qué capas deben utilizarse;
* qué dependencias son válidas;
* qué responsabilidades corresponden a cada componente;
* qué artefactos debe contener una implementación;
* qué patrones deben replicarse;
* cómo se valida la conformidad arquitectónica.

La arquitectura define cómo construir.

El dominio define qué construir.

6. PRINCIPIOS FUNDAMENTALES

6.1 El código debe revelar su propio propósito

El propósito de un componente debe poder inferirse a partir de:

* su ubicación;
* su nombre;
* su interfaz;
* sus dependencias;
* sus tipos;
* su relación con otros componentes;
* sus pruebas;
* su documentación próxima;
* sus restricciones.

Un componente cuyo propósito solo puede conocerse mediante conocimiento externo representa una pérdida de señal arquitectónica.

6.2 La estructura debe comunicar intención

Los nombres de archivos, carpetas, módulos, capas y componentes son parte de la arquitectura.

La estructura física no debe ser accidental.

Cada ubicación debe comunicar:

* responsabilidad;
* alcance;
* nivel de abstracción;
* dirección de dependencias;
* ciclo de vida;
* relación con otros componentes.

6.3 Los patrones deben demostrarse, no solamente describirse

Una regla documentada sin una implementación canónica es insuficiente.

Todo patrón importante debe contar con al menos un ejemplo representativo dentro del repositorio.

Un ejemplo canónico debe ser:

* correcto;
* completo;
* actualizado;
* pequeño;
* localizable;
* coherente con la documentación;
* adecuado para ser replicado.

6.4 Las decisiones críticas deben ser verificables

Los documentos orientan.

Los nombres orientan.

Los ejemplos orientan.

Las herramientas, tipos, pruebas, contratos y políticas ejecutables hacen cumplir.

Toda regla arquitectónica susceptible de automatización debe convertirse en una validación ejecutable.

6.5 La documentación no distingue entre destinatarios

No debe existir una documentación arquitectónica separada exclusivamente para una clase particular de consumidor.

La misma documentación debe servir para:

* desarrolladores;
* revisores;
* arquitectos;
* herramientas de análisis;
* automatizaciones;
* agentes de desarrollo;
* procesos de incorporación;
* auditorías técnicas.

La documentación debe estar diseñada alrededor del sistema, no alrededor del lector.

6.6 El contexto debe ser jerárquico

La información debe ubicarse en el nivel más cercano donde siga siendo válida.

Jerarquía recomendada:

* principios globales;
* arquitectura del sistema;
* decisiones arquitectónicas;
* reglas del módulo;
* contratos del componente;
* detalles de implementación.

La información global no debe repetirse en cada módulo.

La información local no debe elevarse innecesariamente a la documentación global.

6.7 La señal debe ser proporcional

La Wax Foundation no debe llenar todo el espacio.

Debe marcar únicamente la geometría necesaria.

El repositorio debe evitar:

* documentación redundante;
* reglas obvias;
* explicaciones línea por línea;
* convenciones duplicadas;
* comentarios narrativos;
* instrucciones contradictorias;
* ejemplos incompletos;
* abstracciones sin propósito.

6.8 El repositorio debe preservar su capacidad inductiva

Cada cambio debe dejar el repositorio igualmente preparado o mejor preparado para el siguiente participante.

Un cambio no se considera completo cuando solamente funciona.

También debe:

* respetar los patrones existentes;
* mantener la claridad estructural;
* conservar la trazabilidad;
* actualizar los contratos afectados;
* preservar los ejemplos canónicos;
* mantener válida la documentación;
* evitar introducir ambigüedad arquitectónica.

6.9 Los estándares de industria son parte de la señal

La arquitectura no debe redefinir conceptos para los que ya existen convenciones ampliamente comprendidas.

Debe preferirse:

* terminología estándar;
* protocolos estándar;
* formatos estándar;
* convenciones del ecosistema;
* patrones reconocibles;
* principios de diseño consolidados.

La innovación debe concentrarse en los elementos que aporten una ventaja real.

6.10 La consistencia local debe reflejar decisiones globales

Una persona o agente no debería necesitar recorrer todo el repositorio para implementar un cambio ordinario.

Una muestra local suficiente debe reflejar:

* la estructura global;
* los patrones aceptados;
* las dependencias permitidas;
* los contratos mínimos;
* las convenciones relevantes.

La arquitectura global debe proyectarse de forma coherente sobre cada unidad local.

7. COMPONENTES DE LA WAX FOUNDATION

7.1 Arquitectura explícita

La arquitectura debe definir formalmente:

* unidades de modularidad;
* responsabilidades de cada capa;
* dirección de dependencias;
* límites entre componentes;
* mecanismos de comunicación;
* ciclo de vida de las operaciones;
* gestión de errores;
* estrategia de extensibilidad;
* mecanismos de validación.

7.2 Estructura física del repositorio

La distribución de carpetas y archivos debe reflejar la arquitectura lógica.

La estructura debe evitar categorías ambiguas como:

* common;
* misc;
* helpers;
* shared;
* utils;
* services;
* general;
* core;

salvo que su responsabilidad esté definida con precisión.

Cada directorio debe representar una categoría arquitectónica inequívoca.

7.3 Nomenclatura

Los nombres deben comunicar:

* qué es el componente;
* qué responsabilidad tiene;
* a qué nivel arquitectónico pertenece;
* qué operación realiza;
* qué contrato implementa;
* qué dependencia representa.

Los nombres genéricos reducen la densidad de señal.

Debe preferirse:

CreateCustomerCommandHandler

sobre:

CustomerService

Debe preferirse:

PostgreSqlCustomerRepository

sobre:

CustomerDataManager

Debe preferirse:

CustomerRegistrationPolicy

sobre:

CustomerHelper

7.4 Código canónico

Cada patrón arquitectónico relevante debe contar con una implementación de referencia.

MACSS debe mantener ejemplos canónicos para:

* creación de módulos;
* definición de contratos;
* implementación de casos de uso;
* exposición de interfaces;
* adaptación de infraestructura;
* gestión de errores;
* configuración de dependencias;
* pruebas unitarias;
* pruebas de integración;
* pruebas arquitectónicas.

Los ejemplos canónicos constituyen la expresión más concreta de la metodología.

7.5 Documentación jerárquica

La documentación mínima recomendada es:

README.md
architecture.md
adr/

README.md debe explicar:

* propósito del proyecto;
* alcance;
* estructura general;
* comandos principales;
* flujo básico de desarrollo;
* enlaces hacia la arquitectura.

architecture.md debe explicar:

* principios arquitectónicos;
* capas;
* módulos;
* responsabilidades;
* dependencias;
* patrones de extensión;
* restricciones;
* ejemplos canónicos;
* validaciones.

adr/ debe registrar decisiones arquitectónicas relevantes.

Cada ADR debe contener:

* contexto;
* decisión;
* alternativas consideradas;
* consecuencias;
* estado;
* fecha;
* componentes afectados.

No se requiere un archivo AGENTS.md para que la metodología funcione.

La arquitectura debe ser comprensible mediante los artefactos estándar del repositorio.

7.6 Pruebas como contratos de funcionamiento

Las pruebas constituyen la representación ejecutable del comportamiento esperado.

En esta metodología, las pruebas no son un artefacto secundario.

Son una de las principales interfaces de control y comprensión del sistema.

Las pruebas deben permitir verificar:

* comportamiento funcional;
* invariantes;
* contratos;
* límites;
* integración;
* compatibilidad;
* restricciones arquitectónicas;
* ausencia de regresiones.

Las pruebas deben ser especialmente legibles para el responsable humano del sistema.

El desarrollador debe poder comprender con precisión:

* qué comportamiento se garantiza;
* qué casos límite están cubiertos;
* qué condiciones no deben modificarse;
* qué riesgos controla cada prueba;
* qué significado tiene una falla.

Las pruebas deben expresar intención, no detalles accidentales de implementación.

7.7 Tipos y contratos

Las reglas que puedan expresarse en el sistema de tipos no deben permanecer únicamente como documentación.

Los tipos deben reducir estados inválidos y hacer visibles:

* entradas;
* salidas;
* errores;
* estados permitidos;
* nulabilidad;
* mutabilidad;
* dependencias;
* efectos.

Los contratos deben definir límites claros entre componentes.

7.8 Restricciones ejecutables

Las reglas arquitectónicas deben verificarse mediante herramientas cuando sea técnicamente posible.

Ejemplos:

* validación de dependencias;
* restricciones de importación;
* reglas entre capas;
* detección de ciclos;
* validación de nomenclatura;
* verificación de estructura;
* análisis estático;
* comprobación de contratos;
* cobertura de pruebas;
* validación de esquemas;
* políticas de integración continua.

7.9 Comentarios semánticos

Los comentarios son un mecanismo disponible, pero no constituyen el centro de esta especificación.

Solo deben utilizarse cuando la intención no pueda comunicarse adecuadamente mediante:

* estructura;
* nombres;
* tipos;
* contratos;
* código;
* pruebas;
* documentación próxima.

Los comentarios deben explicar decisiones, restricciones o razones no evidentes.

No deben narrar operaciones visibles en el código.

7.10 Estándares de industria

La Wax Foundation debe integrar los estándares relevantes del ecosistema tecnológico utilizado.

Esto incluye, cuando corresponda:

* convenciones de lenguaje;
* estándares de API;
* formatos de documentación;
* especificaciones de seguridad;
* protocolos de interoperabilidad;
* patrones arquitectónicos;
* mecanismos de observabilidad;
* estrategias de versionado;
* prácticas de integración continua.

8. AGENT STEERABILITY

8.1 Definición

Agent Steerability es la capacidad de una arquitectura para inducir de manera consistente extensiones correctas por parte de agentes de desarrollo.

Un agente de desarrollo puede ser:

* una persona;
* un equipo;
* una herramienta;
* un proceso automatizado;
* un sistema autónomo o semiautónomo.

La propiedad no depende de la naturaleza del agente.

Depende de la capacidad del repositorio para orientar su comportamiento.

8.2 Definición probabilística

Agent Steerability es la probabilidad de que un agente, al observar una muestra local suficiente del repositorio, produzca un cambio compatible con las decisiones globales del sistema.

Puede representarse conceptualmente como:

AS = P(C | L, A)

Donde:

AS = Agent Steerability

C = cambio compatible con la arquitectura

L = muestra local suficiente del repositorio

A = arquitectura observable

8.3 Cambio compatible

Un cambio es compatible cuando:

* respeta los límites modulares;
* utiliza las capas correctas;
* mantiene la dirección de dependencias;
* replica patrones aceptados;
* satisface los contratos;
* supera las validaciones;
* conserva la coherencia estructural;
* no introduce una arquitectura paralela;
* actualiza los artefactos relacionados;
* mantiene o mejora la capacidad inductiva del repositorio.

8.4 Muestra local suficiente

Una muestra local suficiente es el conjunto mínimo de elementos que permite inferir correctamente cómo implementar una modificación.

Puede incluir:

* estructura del módulo;
* uno o más ejemplos canónicos;
* interfaces relacionadas;
* pruebas equivalentes;
* sección relevante de architecture.md;
* ADR aplicables;
* reglas automatizadas.

Una buena arquitectura minimiza el tamaño de la muestra necesaria sin perder precisión.

8.5 Propiedades asociadas

Agent Steerability depende de:

* consistencia;
* localidad;
* claridad;
* repetibilidad;
* verificabilidad;
* trazabilidad;
* baja ambigüedad;
* densidad de señal;
* calidad de ejemplos;
* estabilidad de convenciones.

8.6 Objetivo

El objetivo no es alcanzar obediencia absoluta.

El objetivo es aumentar significativamente la probabilidad de que una extensión razonable siga la arquitectura correcta sin requerir instrucciones externas extensas.

9. DENSIDAD DE SEÑAL

9.1 Definición

La densidad de señal representa la proporción de información arquitectónicamente útil respecto del volumen total de información disponible.

Una señal es útil cuando reduce la incertidumbre sobre:

* responsabilidad;
* ubicación;
* dependencia;
* extensión;
* validación;
* intención;
* compatibilidad.

9.2 Señales de alta calidad

Son señales de alta calidad:

* nombres precisos;
* estructura consistente;
* contratos pequeños;
* ejemplos canónicos;
* pruebas legibles;
* documentación localizada;
* reglas ejecutables;
* decisiones trazables;
* errores explícitos;
* dependencias unidireccionales.

9.3 Ruido arquitectónico

Constituye ruido:

* duplicación;
* nombres genéricos;
* carpetas ambiguas;
* patrones alternativos sin justificación;
* documentación obsoleta;
* comentarios redundantes;
* abstracciones innecesarias;
* pruebas acopladas a detalles internos;
* reglas contradictorias;
* archivos sin responsabilidad clara;
* código muerto;
* dependencias implícitas.

9.4 Regla de optimización

Toda incorporación de información debe evaluarse según la siguiente pregunta:

¿Esta señal reduce una ambigüedad arquitectónica real?

Si la respuesta es negativa, probablemente constituye ruido.

10. HARNESS ENGINEERING

10.1 Relación con la arquitectura inductiva

Harness Engineering es una disciplina complementaria.

La arquitectura inductiva define la geometría correcta.

El harness controla el espacio operativo dentro del cual se construye.

En la analogía apícola:

* la Wax Foundation define el patrón de las celdas;
* el marco sostiene la lámina;
* la caja establece los límites físicos;
* la inspección verifica el resultado.

10.2 Diferencia conceptual

Inductive Architecture Engineering:

* orienta;
* comunica;
* demuestra;
* induce;
* organiza el contexto;
* reduce ambigüedad.

Harness Engineering:

* limita;
* automatiza;
* ejecuta;
* valida;
* bloquea desviaciones;
* controla herramientas y procesos.

10.3 Relación recomendada

La arquitectura inductiva debe funcionar aun sin un harness específico.

El harness debe reforzarla.

No debe sustituirla.

Una arquitectura incomprensible con muchas restricciones automatizadas sigue siendo una arquitectura de baja calidad.

Una arquitectura clara sin validaciones automáticas sigue siendo vulnerable a desviaciones.

La combinación recomendada es:

Wax Foundation + Harness = orientación + cumplimiento

11. AGENT READINESS

11.1 Definición de uso

Agent Readiness es la capacidad operativa de un repositorio para ser comprendido, modificado, validado y mantenido por distintos agentes de desarrollo.

La metodología utilizará Agent Readiness como marco de evaluación, no como fundamento conceptual.

11.2 Relación con Agent Steerability

Agent Readiness evalúa si el repositorio está preparado para ser trabajado.

Agent Steerability evalúa si la arquitectura induce cambios compatibles.

Un repositorio puede estar operativo, compilar correctamente y disponer de pruebas, pero aun así presentar baja steerability si:

* existen múltiples patrones para la misma tarea;
* la estructura es ambigua;
* los nombres son inconsistentes;
* las decisiones globales no aparecen en los módulos;
* los ejemplos canónicos no están claros.

11.3 Evaluaciones recomendadas

La arquitectura debe someterse periódicamente a evaluaciones que midan:

* descubribilidad;
* claridad estructural;
* reproducibilidad;
* calidad de documentación;
* confiabilidad de pruebas;
* precisión de contratos;
* coherencia de patrones;
* cumplimiento de límites;
* costo de contexto;
* tasa de cambios compatibles;
* cantidad de correcciones necesarias;
* grado de intervención externa.

11.4 Evals arquitectónicos

Los evals deben utilizar tareas representativas como:

* agregar una nueva funcionalidad;
* crear un nuevo módulo;
* implementar un adaptador;
* modificar un contrato;
* añadir una operación;
* corregir un defecto;
* extender una integración;
* incorporar una nueva validación.

Cada tarea debe evaluarse según:

* ubicación elegida;
* patrón utilizado;
* dependencias introducidas;
* artefactos creados;
* pruebas agregadas;
* cumplimiento de contratos;
* conformidad con architecture.md;
* ausencia de desviaciones;
* cantidad de contexto externo requerido.

11.5 Mejora iterativa

Los resultados de los evals deben utilizarse para modificar la Wax Foundation.

Cuando varios agentes cometen la misma desviación, debe asumirse inicialmente que existe una deficiencia en la señal arquitectónica.

La respuesta no debe ser agregar inmediatamente una instrucción.

Debe evaluarse, en este orden:

1. ¿La estructura es ambigua?

2. ¿El nombre es impreciso?

3. ¿Falta un ejemplo canónico?

4. ¿Existen patrones contradictorios?

5. ¿La regla puede expresarse mediante tipos?

6. ¿La regla puede verificarse automáticamente?

7. ¿La documentación está demasiado lejos del punto de uso?

8. ¿La documentación contiene ruido?

9. ¿Es necesaria una aclaración documental?

10. MACSS COMO ARQUITECTURA INDUCTIVA

12.1 Definición

MACSS significa:

Modular Architecture for Comprehensive Software Solutions

MACSS debe evolucionar para ser una arquitectura modular e inductiva.

Su implementación debe permitir que la estructura del repositorio enseñe cómo desarrollar soluciones completas y coherentes.

12.2 Propósito de la Wax Foundation en MACSS

La Wax Foundation de MACSS debe enseñar:

* cómo se define un módulo;
* cómo se delimita una responsabilidad;
* cómo se organiza una funcionalidad;
* cómo se conectan las capas;
* cómo se expresan contratos;
* cómo se implementan adaptadores;
* cómo se validan dependencias;
* cómo se escriben pruebas;
* cómo se agregan nuevas capacidades;
* cómo se preserva la modularidad.

12.3 Restricción de alcance

La Wax Foundation de MACSS no debe intentar describir cada dominio posible.

Debe limitarse a proporcionar la geometría arquitectónica común.

Cada solución concreta podrá añadir documentación de dominio sin alterar el modelo base.

12.4 Repetibilidad estructural

Los módulos MACSS deben compartir una geometría reconocible.

La repetibilidad debe permitir que, después de comprender un módulo representativo, sea posible navegar y extender otros módulos con bajo costo cognitivo.

La repetición no debe ser mecánica.

Solo deben repetirse los elementos que representen responsabilidades arquitectónicas reales.

12.5 Variabilidad controlada

MACSS debe distinguir entre:

* elementos obligatorios;
* elementos opcionales;
* puntos de extensión;
* variaciones permitidas;
* variaciones prohibidas.

La arquitectura debe impedir que cada módulo interprete libremente sus capas y responsabilidades.

13. DOCUMENTACIÓN BASE DE MACSS

13.1 README.md

README.md debe contener:

* propósito de MACSS;
* principios fundamentales;
* estructura general;
* inicio rápido;
* comandos principales;
* enlace a architecture.md;
* enlace a ADR;
* referencia a ejemplos canónicos.

13.2 architecture.md

architecture.md debe ser la fuente principal de la arquitectura.

Debe contener:

1. Propósito
2. Principios
3. Modelo de módulos
4. Capas
5. Responsabilidades
6. Dirección de dependencias
7. Flujo de una operación
8. Contratos
9. Adaptadores
10. Gestión de errores
11. Pruebas
12. Restricciones
13. Estructura del repositorio
14. Ejemplos canónicos
15. Procedimiento para agregar funcionalidades
16. Procedimiento para crear módulos
17. Validaciones automatizadas
18. Antipatrones
19. Criterios de conformidad

13.3 ADR

Los ADR deben utilizarse para decisiones que:

* afecten más de un componente;
* modifiquen la arquitectura;
* introduzcan una dependencia relevante;
* cambien un contrato global;
* creen un nuevo patrón;
* reemplacen una convención;
* introduzcan un trade-off permanente.

No debe crearse un ADR para decisiones locales triviales.

13.4 Código como documentación primaria

README.md y architecture.md deben describir el sistema.

El código canónico debe demostrarlo.

Las pruebas deben verificarlo.

Las herramientas deben hacerlo cumplir.

14. CRITERIOS DE CONFORMIDAD

Una implementación cumple con la metodología cuando:

* la ubicación de cada componente refleja su responsabilidad;
* los nombres comunican intención;
* existe una dirección clara de dependencias;
* los patrones importantes tienen ejemplos canónicos;
* las pruebas expresan contratos;
* las decisiones globales están documentadas;
* las reglas automatizables están automatizadas;
* la documentación es jerárquica;
* no existe documentación exclusiva para una herramienta;
* la estructura puede navegarse sin conocimiento oculto;
* las extensiones ordinarias requieren poco contexto externo;
* los cambios preservan la coherencia;
* las desviaciones son detectables;
* el repositorio mantiene una alta densidad de señal.

15. ANTIPATRONES

15.1 Arquitectura declarativa sin evidencia

La documentación afirma una arquitectura que el código no respeta.

15.2 Patrones múltiples no gobernados

Existen varias formas de implementar la misma responsabilidad sin una decisión explícita.

15.3 Carpetas contenedoras genéricas

Componentes heterogéneos se agrupan bajo nombres ambiguos.

15.4 Ejemplos canónicos incompletos

Los ejemplos de referencia omiten validaciones, pruebas o integración real.

15.5 Documentación orientada a una herramienta

Las reglas arquitectónicas dependen de un formato o proveedor específico.

15.6 Dependencias implícitas

Un componente depende de convenciones, orden de ejecución o estado externo no expresado.

15.7 Tests como copia de la implementación

Las pruebas verifican detalles internos en lugar de contratos observables.

15.8 Restricciones únicamente textuales

Una regla automatizable permanece como recomendación documental.

15.9 Sobredocumentación

La cantidad de texto dificulta encontrar las señales importantes.

15.10 Convenciones sin propósito

Se exige una estructura uniforme que no representa responsabilidades reales.

15.11 Arquitectura paralela

Una nueva funcionalidad introduce capas, patrones o rutas alternativas sin una decisión formal.

15.12 Conocimiento tribal

El desarrollo correcto depende de información no presente en el repositorio.

16. MÉTRICAS

16.1 Tasa de conformidad arquitectónica

Porcentaje de cambios que respetan la arquitectura sin correcciones estructurales.

16.2 Tamaño de contexto mínimo

Cantidad de archivos o información necesaria para implementar correctamente una tarea representativa.

16.3 Tasa de desviación

Porcentaje de cambios que:

* eligen una ubicación incorrecta;
* introducen dependencias inválidas;
* crean patrones paralelos;
* omiten contratos;
* incumplen restricciones.

16.4 Densidad de patrones canónicos

Proporción de patrones arquitectónicos relevantes que cuentan con ejemplos completos y actualizados.

16.5 Cobertura de restricciones

Proporción de reglas arquitectónicas que poseen validación ejecutable.

16.6 Tasa de intervención

Cantidad de instrucciones externas necesarias para que una implementación sea compatible.

16.7 Consistencia entre módulos

Grado en que módulos equivalentes presentan una estructura reconocible y predecible.

16.8 Preservación contextual

Porcentaje de cambios que actualizan correctamente documentación, pruebas, contratos y ejemplos relacionados.

16.9 Entropía arquitectónica

Cantidad de formas distintas existentes para resolver una misma categoría de problema.

Una alta entropía reduce Agent Steerability.

16.10 Índice de señal

Relación entre señales arquitectónicas útiles y artefactos redundantes, ambiguos u obsoletos.

17. PROCESO DE DISEÑO

17.1 Identificar operaciones arquitectónicas recurrentes

Ejemplos:

* crear un módulo;
* agregar un caso de uso;
* definir una interfaz;
* implementar un adaptador;
* añadir una prueba;
* registrar una dependencia.

17.2 Definir una geometría única

Para cada operación recurrente debe definirse:

* ubicación;
* nombre;
* responsabilidades;
* dependencias;
* contratos;
* pruebas;
* validaciones.

17.3 Construir ejemplos canónicos

Cada operación debe estar demostrada mediante una implementación de referencia.

17.4 Eliminar patrones contradictorios

El repositorio debe converger hacia una forma preferida.

Los patrones obsoletos deben:

* migrarse;
* aislarse;
* marcarse claramente;
* eliminarse.

17.5 Automatizar restricciones

Las decisiones que puedan validarse deben trasladarse a herramientas.

17.6 Ejecutar evals

Se deben probar tareas representativas sobre el repositorio.

17.7 Analizar desviaciones

Toda desviación repetida debe interpretarse como una señal de ambigüedad.

17.8 Refinar la Wax Foundation

La arquitectura debe ajustarse reduciendo ambigüedad y ruido.

17.9 Verificar preservación

Cada cambio arquitectónico debe comprobar que los patrones locales siguen representando correctamente las decisiones globales.

18. PRINCIPIO DE CONTINUIDAD

Cada cambio debe dejar el repositorio igualmente preparado o mejor preparado para el siguiente agente.

Esto implica:

* no introducir excepciones silenciosas;
* no crear convenciones privadas;
* no depender de memoria externa;
* no duplicar decisiones;
* no romper ejemplos canónicos;
* no degradar pruebas;
* no reducir trazabilidad;
* no aumentar innecesariamente la entropía;
* no ocultar responsabilidades.

Un cambio que funciona pero reduce la capacidad del repositorio para orientar desarrollos futuros genera deuda contextual.

19. DEUDA CONTEXTUAL

La deuda contextual es la pérdida acumulada de capacidad del repositorio para explicar y hacer cumplir su propia arquitectura.

Se produce cuando:

* el código y la documentación divergen;
* los nombres dejan de representar responsabilidades;
* aparecen excepciones no documentadas;
* se duplican patrones;
* se eliminan pruebas contractuales;
* las reglas se vuelven implícitas;
* aumenta el conocimiento tribal;
* las herramientas dejan de validar decisiones;
* los ejemplos canónicos quedan obsoletos.

La deuda contextual debe tratarse como una forma de deuda arquitectónica.

20. FORMULACIÓN OFICIAL

MACSS adopta la Ingeniería de Arquitectura Inductiva como práctica para diseñar repositorios que expresen estructuralmente su forma correcta de extensión.

La Architectural Wax Foundation de MACSS es el conjunto mínimo, coherente y verificable de señales arquitectónicas presentes en la estructura, el código, los contratos, las pruebas, la documentación, los ejemplos y las restricciones del repositorio.

Su propósito es inducir extensiones compatibles con las decisiones globales de MACSS mediante una alta densidad de señal, baja ambigüedad, patrones canónicos y validaciones ejecutables.

La Wax Foundation no describe todas las implementaciones posibles.

Define la geometría necesaria para que el sistema pueda crecer sin perder su forma.

21. DEFINICIÓN BREVE

Inductive Architecture Engineering es la práctica de diseñar una arquitectura para que su propósito, sus reglas de composición y su forma correcta de extensión puedan inferirse directamente del repositorio.

Architectural Wax Foundation es el molde semántico formado por la estructura, el código canónico, los contratos, las pruebas, la documentación, los estándares y las restricciones que inducen ese comportamiento.

Agent Steerability es la probabilidad de que un agente, después de observar una muestra local suficiente del repositorio, produzca un cambio compatible con las decisiones globales de la arquitectura.

22. MANIFIESTO

Preferimos:

* arquitectura observable sobre arquitectura declarada;
* señales estructurales sobre instrucciones aisladas;
* ejemplos canónicos sobre descripciones abstractas;
* contratos verificables sobre convenciones implícitas;
* nombres precisos sobre categorías genéricas;
* contexto localizado sobre documentación centralizada indiscriminadamente;
* pruebas como contratos sobre pruebas como formalidad;
* estándares reconocibles sobre terminología innecesariamente propietaria;
* una forma preferida sobre múltiples alternativas equivalentes;
* restricciones ejecutables sobre recomendaciones;
* densidad de señal sobre volumen documental;
* continuidad arquitectónica sobre funcionalidad aislada;
* repositorios autoexplicativos sobre conocimiento tribal.

El sistema debe enseñar cómo continuar construyéndolo.
