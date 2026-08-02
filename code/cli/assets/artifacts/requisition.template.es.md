# Solicitud

<!-- macss:lang=es · Idioma de esta solicitud y de TODOS sus artefactos derivados (especificación, issues, planes). Mantener consistente. No se renderiza en el PDF/DOCX. -->

> **Todos los campos de esta solicitud son obligatorios.**
> Estructura basada en *Gap Analysis* — BABOK® v3 (IIBA), cap. 8.
> Terminología de dominio alineada con *Ubiquitous Language* — Domain-Driven Design (Eric Evans, 2003).

## Metadatos

| Campo       | Valor                                          |
| ----------- | ---------------------------------------------- |
| Sistema     | <!-- Valor del catálogo oficial -->            |
| Proyecto    | <!-- Ej. Motores Fase 2 -->                    |
| Solicitante | <!-- Nombre — Área de Procesos -->             |
| Fecha       | {{DATE}}                                       |
| Contacto    | <!-- Nombre y medio de contacto -->            |

**Urgencia:**

- [ ] Crítica
- [ ] Alta
- [ ] Normal

## 1. Necesidad y valor

<!-- BABOK® — Business Need. Tres preguntas cortas: una frase cada una.
     Sólo usted tiene estas respuestas; nadie las puede escribir por usted. -->

**¿Qué problema resuelve?**

<!-- Su respuesta aquí -->

> **Ejemplo:** *"Se pierden registros de facturas cuando dos analistas editan el archivo a la vez."*

**¿A quién afecta?**

<!-- Su respuesta aquí -->

> **Ejemplo:** *"A los cuatro analistas de Cuentas por Pagar, todos los días."*

**¿Qué pasa si no se hace?**

<!-- Su respuesta aquí -->

> **Ejemplo:** *"Seguimos rehaciendo el cierre mensual y arrastrando diferencias que se detectan tarde."*

<!-- La cuarta pregunta ---cómo sabremos que sirvió--- no va aquí: sale del
     análisis con QA y queda en la especificación, porque convertirla en algo
     observable es trabajo de ingeniería, no del solicitante. -->

## 2. Situación actual

<!-- BABOK® — Current State Description -->

> Describa cómo se hace **hoy** lo que quiere cambiar. Si es algo nuevo que no existe, escriba: *"No existe actualmente"*.

<!-- Su respuesta aquí -->

> **Ejemplo:** *"Actualmente el registro de facturas se realiza en una hoja de Excel compartida. Cada analista abre el archivo, localiza la última fila e ingresa los datos manualmente. En ocasiones dos personas editan simultáneamente y se pierden registros."*

<!-- Usar el lenguaje ubicuo del dominio (Ubiquitous Language — DDD). -->

## 3. Situación deseada

<!-- BABOK® — Future State Description -->

> Describa cómo **quiere que funcione** en el futuro. No necesita dar la solución técnica, solo el resultado esperado.

<!-- Su respuesta aquí -->

> **Ejemplo:** *"El sistema debe contar con un formulario de registro de facturas con los campos: número, monto, proveedor y fecha. No debe permitir registros duplicados. Al guardar, la información debe quedar disponible para todos los usuarios sin riesgo de pérdida."*

<!-- Usar el lenguaje ubicuo del dominio (Ubiquitous Language — DDD). -->

## Anexos

<!-- Capturas, documentos, ejemplos, mockups, diagramas, correos previos o cualquier material de apoyo. -->
